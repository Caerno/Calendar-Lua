#!/usr/bin/env python3
"""Bridge between this repo and ru.wikipedia.

Usage:
  ./sync.py status                     - compare repo files with wiki pages
  ./sync.py diff <file>                - line diff, wiki vs repo
  ./sync.py pull [<file>|all]          - wiki -> repo
  ./sync.py push [<file>|all] -m "edit summary" [--minor]
                                       - repo -> wiki (needs a BotPassword)

Credentials: ~/.config/wiki-sync.env with
  WSYNC_USER=Name@botname
  WSYNC_PASS=botpassword
or the same environment variables; prompts interactively as a fallback.
"""
import difflib
import getpass
import http.cookiejar
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://ru.wikipedia.org/w/api.php"
RAW = "https://ru.wikipedia.org/w/index.php"
ROOT = os.path.dirname(os.path.abspath(__file__))

# repo file -> wiki page
PAGES = {
    "modules/calendar.lua": "Модуль:Calendar",
    "modules/sandbox.lua": "Модуль:Песочница/Carn/Calendar",  # working sandbox
    "modules/sandbox-doc.wt": "Модуль:Песочница/Carn/Calendar/doc",
    "modules/testcases.lua": "Модуль:Calendar/testcases",
    "modules/testcases-doc.wt": "Модуль:Calendar/testcases/doc",
    "modules/yesno.lua": "Модуль:Yesno",
    "doc.wt": "Модуль:Calendar/doc",
    # personal sandbox mirrors
    "carn-sandbox/Carn.lua": "Модуль:Песочница/Carn",
    "carn-sandbox/Carn-doc.wt": "Модуль:Песочница/Carn/doc",
    "carn-sandbox/Text.lua": "Модуль:Песочница/Carn/Text",
    "carn-sandbox/Frame.lua": "Модуль:Песочница/Carn/Frame",
    "carn-sandbox/Randc.lua": "Модуль:Песочница/Carn/Randc",
    "carn-sandbox/Unicode.lua": "Модуль:Песочница/Carn/Unicode",
    "carn-sandbox/wikibase.lua": "Модуль:Песочница/Carn/wikibase",
}
# pull-only pages are third-party shared modules
PUSH_ALLOWED = {"modules/calendar.lua", "modules/sandbox.lua", "modules/sandbox-doc.wt",
                "doc.wt", "modules/testcases.lua", "modules/testcases-doc.wt",
                "carn-sandbox/Text.lua"}


class Wiki:
    def __init__(self):
        jar = http.cookiejar.CookieJar()
        self.op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
        self.op.addheaders = [("User-Agent", "Calendar-Lua-sync/1.1 (ru:User:Carn)")]

    def api(self, **params):
        params.setdefault("format", "json")
        data = urllib.parse.urlencode(params).encode()
        with self.op.open(API, data) as r:
            return json.load(r)

    def raw(self, title):
        """Page text, or None if the page does not exist."""
        url = RAW + "?" + urllib.parse.urlencode({"title": title, "action": "raw"})
        try:
            with self.op.open(url) as r:
                return r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            raise

    def login(self):
        env_file = os.path.expanduser("~/.config/wiki-sync.env")
        if os.path.exists(env_file):
            for line in open(env_file, encoding="utf-8"):
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, _, v = line.partition("=")
                    os.environ.setdefault(k.strip(), v.strip().strip("'\""))
        user = os.environ.get("WSYNC_USER") or input("Login (Name@botname): ")
        pw = os.environ.get("WSYNC_PASS") or getpass.getpass("Bot password: ")
        token = self.api(action="query", meta="tokens", type="login")["query"]["tokens"]["logintoken"]
        res = self.api(action="login", lgname=user, lgpassword=pw, lgtoken=token)
        if res.get("login", {}).get("result") != "Success":
            sys.exit(f"login failed: {res}")

    def edit(self, title, text, summary, minor=False):
        """Save the page; returns True on success."""
        csrf = self.api(action="query", meta="tokens")["query"]["tokens"]["csrftoken"]
        params = {"action": "edit", "title": title, "text": text,
                  "summary": summary, "token": csrf, "assert": "user"}
        if minor:
            params["minor"] = 1
        res = self.api(**params)
        err = res.get("error")
        if err:
            print(f"✘ {title}: {err.get('code')} — {err.get('info', '')[:120]}")
            return False
        info = res.get("edit", {})
        print(f"✔ {title}: {info.get('result')} "
              f"(oldrevid={info.get('oldrevid')}, newrevid={info.get('newrevid')})")
        return True


def local_text(path):
    full = os.path.join(ROOT, path)
    if not os.path.exists(full):
        return None
    with open(full, encoding="utf-8") as f:
        return f.read()


def norm(s):
    return s.rstrip("\n") if s is not None else None


def cmd_status(wiki):
    for path, title in PAGES.items():
        loc, rem = norm(local_text(path)), norm(wiki.raw(title))
        if loc is None and rem is None:
            state = "missing on both sides"
        elif loc is None:
            state = "missing locally (pull it)"
        elif rem is None:
            state = "missing on wiki"
        elif loc == rem:
            state = "= in sync"
        else:
            state = "≠ DIFFERS"
        print(f"{state:28} {path} ↔ {title}")


def cmd_pull(wiki, target):
    for path, title in PAGES.items():
        if target not in ("all", path):
            continue
        rem = wiki.raw(title)
        if rem is None:
            print(f"— {title}: no such page, skipping")
            continue
        full = os.path.join(ROOT, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8", newline="\n") as f:
            f.write(rem.rstrip("\n") + "\n")
        print(f"✔ {title} → {path} ({len(rem.encode('utf-8'))} bytes)")


def cmd_diff(wiki, path):
    title = PAGES[path]
    loc, rem = norm(local_text(path)), norm(wiki.raw(title))
    if loc is None or rem is None:
        sys.exit("one side is missing — see status")
    for line in difflib.unified_diff(rem.splitlines(), loc.splitlines(),
                                     fromfile=f"wiki:{title}", tofile=f"repo:{path}", lineterm=""):
        print(line)


def cmd_push(wiki, target, summary, minor):
    if target == "all":
        paths = [p for p in PAGES if p in PUSH_ALLOWED]
    else:
        if target not in PAGES:
            sys.exit(f"{target}: not in the page map")
        if target not in PUSH_ALLOWED:
            sys.exit(f"{target}: pull-only (third-party shared module)")
        paths = [target]
    queue = []
    for path in paths:
        loc = local_text(path)
        if loc is None:
            if target != "all":
                sys.exit(f"{path}: file not found")
            continue
        if norm(loc) == norm(wiki.raw(PAGES[path])):
            if target != "all":
                print(f"= {PAGES[path]}: already in sync, nothing to push")
            continue
        queue.append((path, loc))
    if not queue:
        print("nothing to push")
        return
    wiki.login()
    failed = 0
    for path, loc in queue:
        if not wiki.edit(PAGES[path], norm(loc), summary, minor):
            failed += 1
    if failed:
        sys.exit(1)


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    wiki = Wiki()
    cmd = args[0]
    if cmd == "status":
        cmd_status(wiki)
    elif cmd == "pull":
        cmd_pull(wiki, args[1] if len(args) > 1 else "all")
    elif cmd == "diff":
        cmd_diff(wiki, args[1])
    elif cmd == "push":
        minor = "--minor" in args
        args = [a for a in args if a != "--minor"]
        if "-m" not in args:
            sys.exit('push requires -m "edit summary"')
        summary = args[args.index("-m") + 1]
        target = args[1] if len(args) > 1 and args[1] != "-m" else "all"
        cmd_push(wiki, target, summary, minor)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
