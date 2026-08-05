# Calendar-Lua

Development mirror and tooling for [Module:Calendar](https://ru.wikipedia.org/wiki/Module:Calendar)
on Russian Wikipedia: date conversion between calendars (Gregorian, Julian and Coptic computed
via Julian Day Number, plus six calendars natively supported by MediaWiki `#time`), old-style/new-style
date rendering, Nth-weekday-of-month computation and UTC offset formatting.

## Layout

| Path | Contents |
|---|---|
| `modules/` | mirrors of wiki pages: `calendar.lua` = Module:Calendar, `sandbox.lua` = working sandbox, `testcases.lua` + `*-doc.wt` docs |
| `doc.wt` | Module:Calendar/doc |
| `lualib/` | partial MediaWiki Scribunto environment for local runs |
| `carn-sandbox/` | snapshots of personal sandbox modules |
| `sync.py` | bridge between the repo and the wiki: `status` / `diff` / `pull` / `push` |
| `deploy.sh` | push helper |
| `.github/workflows/` | `ci.yml` — luacheck on every push; `deploy.yml` — manual dispatch |

## Workflow

The wiki is the canonical store; this repo tracks it and stages changes.

```
./sync.py status                 # what differs
./sync.py pull all               # wiki -> repo
./sync.py diff doc.wt            # inspect a difference
./deploy.sh "edit summary"       # repo -> wiki, all changed files
./deploy.sh -m "typo" doc.wt     # single file, marked as a minor edit
```

Credentials: `~/.config/wiki-sync.env` with `WSYNC_USER=Name@botname` and
`WSYNC_PASS=...` from [Special:BotPasswords](https://ru.wikipedia.org/wiki/Special:BotPasswords).

Deploys run locally: GitHub-hosted runners are globally IP-blocked by Wikimedia
as open proxies, so `deploy.yml` works only from a self-hosted runner or another
allowed host.

## Testing

- On-wiki: [Module:Calendar/testcases](https://ru.wikipedia.org/wiki/Модуль:Calendar/testcases)
  on top of Модуль:UnitTests (entry point `run_tests`); results render on the
  testcases documentation page.
- CI: `luacheck modules/ --globals mw frame` — warnings pass, errors fail.

## Licensing

Two parts, see [LICENSE](LICENSE):

- everything except `lualib/` — wiki content and tooling, **CC BY-SA 4.0**;
  attribution for the wiki content via the linked page histories;
- `lualib/` — MediaWiki Scribunto, **GPL-2.0-or-later**, see [COPYING](COPYING).
