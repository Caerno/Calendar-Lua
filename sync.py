#!/usr/bin/env python3
"""Мост вики ↔ git для Calendar-Lua.

Команды:
  ./sync.py status                    - что разошлось между репой и вики
  ./sync.py diff modules/sandbox.lua  - построчный дифф локальный↔вики
  ./sync.py pull [файл|all]           - вики → локальные файлы
  ./sync.py push modules/sandbox.lua -m "комментарий правки"
                                      - локальный файл → вики (нужен BotPassword)

Push требует учётку: Special:BotPasswords на ruwiki → создать бот-пароль
(права: Edit existing pages + Create, edit, and move pages), затем:
  export WSYNC_USER='Carn@имябота'  WSYNC_PASS='пароль'
Без переменных окружения спросит интерактивно.
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

# файл в репе → страница вики
PAGES = {
    "modules/calendar.lua": "Модуль:Calendar",
    "modules/sandbox.lua": "Модуль:Песочница/Carn/Calendar",  # рабочая песочница
    "modules/sandbox-doc.wt": "Модуль:Песочница/Carn/Calendar/doc",
    "modules/yesno.lua": "Модуль:Yesno",
    "doc.wt": "Модуль:Calendar/doc",
    # личные песочницы Carn (зеркала)
    "carn-sandbox/Carn.lua": "Модуль:Песочница/Carn",
    "carn-sandbox/Carn-doc.wt": "Модуль:Песочница/Carn/doc",
    "carn-sandbox/Text.lua": "Модуль:Песочница/Carn/Text",
    "carn-sandbox/Frame.lua": "Модуль:Песочница/Carn/Frame",
    "carn-sandbox/Randc.lua": "Модуль:Песочница/Carn/Randc",
    "carn-sandbox/Unicode.lua": "Модуль:Песочница/Carn/Unicode",
    "carn-sandbox/wikibase.lua": "Модуль:Песочница/Carn/wikibase",
}
# что разрешено пушить (чужие общие модули - только pull)
PUSH_ALLOWED = {"modules/calendar.lua", "modules/sandbox.lua", "modules/sandbox-doc.wt",
                "doc.wt", "carn-sandbox/Text.lua"}


class Wiki:
    def __init__(self):
        jar = http.cookiejar.CookieJar()
        self.op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
        self.op.addheaders = [("User-Agent", "Calendar-Lua-sync/1.0 (ru:User:Carn)")]

    def api(self, **params):
        params.setdefault("format", "json")
        data = urllib.parse.urlencode(params).encode()
        with self.op.open(API, data) as r:
            return json.load(r)

    def raw(self, title):
        """Текст страницы или None, если её нет."""
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
        user = os.environ.get("WSYNC_USER") or input("Логин (Имя@бот): ")
        pw = os.environ.get("WSYNC_PASS") or getpass.getpass("Бот-пароль: ")
        token = self.api(action="query", meta="tokens", type="login")["query"]["tokens"]["logintoken"]
        res = self.api(action="login", lgname=user, lgpassword=pw, lgtoken=token)
        if res.get("login", {}).get("result") != "Success":
            sys.exit(f"Логин не удался: {res}")

    def edit(self, title, text, summary):
        csrf = self.api(action="query", meta="tokens")["query"]["tokens"]["csrftoken"]
        res = self.api(action="edit", title=title, text=text, summary=summary,
                       token=csrf, **{"assert": "user"})
        err = res.get("error")
        if err:
            sys.exit(f"Ошибка правки {title}: {err}")
        info = res.get("edit", {})
        print(f"✔ {title}: {info.get('result')} "
              f"(oldrevid={info.get('oldrevid')}, newrevid={info.get('newrevid')})")


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
            state = "нет ни там, ни там"
        elif loc is None:
            state = "нет локально (сделай pull)"
        elif rem is None:
            state = "нет на вики"
        elif loc == rem:
            state = "= синхронно"
        else:
            state = "≠ РАЗОШЛИСЬ"
        print(f"{state:28} {path} ↔ {title}")


def cmd_pull(wiki, target):
    for path, title in PAGES.items():
        if target not in ("all", path):
            continue
        rem = wiki.raw(title)
        if rem is None:
            print(f"— {title}: страницы нет, пропуск")
            continue
        full = os.path.join(ROOT, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8", newline="\n") as f:
            f.write(rem.rstrip("\n") + "\n")
        print(f"✔ {title} → {path} ({len(rem)} байт)")


def cmd_diff(wiki, path):
    title = PAGES[path]
    loc, rem = norm(local_text(path)), norm(wiki.raw(title))
    if loc is None or rem is None:
        sys.exit("Одной из сторон нет — смотри status")
    for line in difflib.unified_diff(rem.splitlines(), loc.splitlines(),
                                     fromfile=f"вики:{title}", tofile=f"репа:{path}", lineterm=""):
        print(line)


def cmd_push(wiki, path, summary):
    if path not in PUSH_ALLOWED:
        sys.exit(f"{path} — только pull (чужой общий модуль)")
    loc = local_text(path)
    if loc is None:
        sys.exit(f"{path} не найден")
    title = PAGES[path]
    if norm(loc) == norm(wiki.raw(title)):
        print(f"= {title} уже совпадает, пушить нечего")
        return
    wiki.login()
    wiki.edit(title, norm(loc), summary)


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
        if "-m" not in args:
            sys.exit("push требует -m \"комментарий правки\"")
        cmd_push(wiki, args[1], args[args.index("-m") + 1])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
