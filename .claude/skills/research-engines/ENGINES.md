# Search engine recipes — shared reference

**This is the single source of truth for search-engine access.** It is not a skill
and cannot be invoked. `research-agent` and `research-compare` both read it.

Engines change their bot behaviour constantly. When a recipe breaks, fix it **here**
and both research modes get the fix. Do not copy this table into a SKILL.md.

Referenced from skills as `~/.claude/skills/research-engines/ENGINES.md`
(resolves through the junction to `C:\Users\Charles\.agents\skills`).

Last tested: 2026-09-17.

## Primary — local SearXNG

**Always search through the script. Never call the endpoint directly.**

```
powershell -NoProfile -File "C:\Users\Charles\.claude\skills\research-engines\search.ps1" "<query>"
powershell -NoProfile -File "C:\Users\Charles\.claude\skills\research-engines\search.ps1" "<query>" -Top 30
```

This box has `powershell` (5.1) only — there is no `pwsh`.

One query, many backends: google cse, bing, brave, duckduckgo, qwant, yandex,
yahoo, yep, baidu, naver, mwmbl and more. Each result carries an `engines` list,
which gives **cross-engine agreement for free** — no need to fan out one agent
per engine to get it.

Returns compact JSON: `n` (how many results existed), `shown` (how many you got),
`blocked` (engines that failed or hit a CAPTCHA this query), and `r[]` with
`t` title, `u` url, `c` snippet, `e` engines.

`-Top` defaults to 10; `-Top 0` returns everything. `-Snippet` defaults to 300
characters. If the script reports `searxng_unreachable`, drop to the fallbacks
below.

**Why the script and not the raw endpoint:** the raw reply is ~30k tokens per
query — 15 fields per result, four of them always empty, pretty-printed. A
researcher re-reads its whole context every turn, and six run in parallel, so
one fat reply is paid for many times over. Trimmed it is ~2k tokens for the same
results, same snippets, same engine tags. Measured 2026-09-17: 31,582 tokens
raw vs ~1,000 trimmed at `-Top 10`, from 64 available results.

Instances:
- System Python instance, source tree at `C:\Users\Charles\repos\searxng`
  (default config, full engine pool). No auto-start on boot.
- PortableSearXNG at `C:\Users\Charles\repos\portable-searxng` — self-contained,
  embedded Python, safety-checked. Start with `start.bat`.

Port 8080 is owned by tailscaled; this kit uses 8888. After a reboot, neither
instance is running — start one before relying on it.

Caveat: the `google` engine itself gets CAPTCHA'd after a few queries. `google cse`
keeps working.

## Link checking — many URLs in one call

```
powershell -NoProfile -File "C:\Users\Charles\.claude\skills\research-engines\checkurls.ps1" "<path to ledger.json or a urls.txt>"
```

Pulls every http(s) URL out of the file, checks them in parallel, returns
`checked`, `live`, a `dead` list with status codes, and `live_urls`.

Never check URLs one at a time. Each check would otherwise be its own turn, and
every turn re-reads the whole context. Measured 2026-09-17: 57 URLs in 6.9
seconds, one turn, ~780 tokens.

## Fallback — direct fetch

Use these when 127.0.0.1:8888 is down.

| Engine | Recipe | Status |
|---|---|---|
| DuckDuckGo | `https://html.duckduckgo.com/html/?q=<query>` | works |
| Bing | `https://www.bing.com/search?q=<query>&count=10` | works |
| Brave | `https://search.brave.com/search?q=<query>` | works |
| Mwmbl | `https://mwmbl.org/search?q=<query>` | works — indie, community index |
| Baidu | `https://www.baidu.com/s?wd=<query>` | works — Chinese web |
| Naver | `https://search.naver.com/search.naver?query=<query>` | works — Korean web |
| Marginalia | `https://search.marginalia.nu/search?query=<query>` | may say "wait 3 seconds"; retry once after a delay. Small/independent web |
| Yandex | `https://yandex.com/search/?text=<query>` | direct fetch blocked; use the browser tool to pass the JS check, or the local SearXNG (has a Yandex backend) |
| SearXNG public | `https://searx.tiekoetter.com/search?q=<query>` (fallback `https://priv.au/search?q=<query>`) | results may be JS-rendered |
| Startpage | `https://www.startpage.com/sp/search?query=<query>` | often blocked (Anubis). Skip gracefully and report "blocked" |

**Blocked via direct fetch — do not waste an agent on these.** Reach them through
the local SearXNG instead: Google, Ecosia, Yahoo, Yep, Stract, Petal, Mojeek.
MetaGer is now paid.

## Failure ladder

When a recipe fails, in order: the browser tool → another SearXNG instance →
skip gracefully and report the engine as **blocked**.

Never claim a blocked engine returned results.

## Credibility scoring

Score every source that reaches a report:

Credibility is about **what the source is**, not how many engines indexed it:

- **HIGH** — official or primary: docs, papers, vendor sites, gov/edu.
- **MEDIUM** — reputable secondary: established media, well-known blogs.
- **LOW** — unknown domains, forums, personal blogs, aggregators.

**Engine agreement is recorded separately, and never promotes a source.** The
old rule said "or confirmed by 2+ engines" for HIGH while also saying forums are
LOW, which contradicts itself — a Reddit thread returned by Brave and Google is
still a Reddit thread. Agreement tells you a URL is real and findable, not that
it is authoritative. `merge_evidence.py` stores it as `agreement` alongside the
credibility the researcher assigned.

Verify key claims against at least two independent sources where possible. Flag
any claim that only one source supports.

## Hard rules

- Never invent a URL. If a page could not be fetched, do not cite it.
- Record which engines returned each source.
- Mark anything guessed or unverifiable as uncertain rather than dropping it
  silently.
