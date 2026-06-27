# Substack Blizzard

Track the rich-text content of Substack Notes as reusable assets, and re-post that
content as fresh Notes over time — keeping a history of every repost.

## Concept

Each blog post has a Substack `Comfy::Cms::Categorization`. Its `#data` (jsonb) holds:

```jsonc
{
  "id":   199807837,                       // Substack post id (legacy)
  "url":  "https://mikeyclarke.substack.com/p/…",  // canonical post URL
  "notes": [ "https://substack.com/…/note/c-…", … ], // legacy flat URL list (retained)
  "blizzard": [
    {
      "text":      "<plaintext — used for matching + display>",
      "body_json": { "type": "doc", "attrs": {…}, "content": [ … ] }, // ProseMirror, lossless
      "notes":     [ { "url": "https://substack.com/…/note/c-…", "timestamp": "2025-08-…Z" }, … ]
    }
  ]
}
```

A **blizzard entry** is one piece of text-content plus every Note that has posted it.
`body_json` is the master copy used for reposting — it preserves bold / italic / links
as ProseMirror marks. `text` is its plaintext rendering.

`#data["notes"]` is the old flat list, kept for now; prune later (like `#scratchpad`).

## The Cloudflare constraint (read this first)

Substack's internal API is reached with a stored `substack.sid` session cookie.

- **Reads work from anywhere**, including the production DigitalOcean server.
- **Note-creation POSTs are blocked by Cloudflare from the datacenter IP** — they 403.
  The identical request succeeds from a **residential IP**.

So: backfilling, re-seeding, and the admin UI run server-side on prod, but **creating
new Notes (reposting) runs from your Mac**.

## Components

- `Substack::Client` — internal-API wrapper (cookie auth). `get_note`, `create_note`,
  `create_attachment`, `delete_note`. Retries 429/502/503/504 with backoff. Raises
  `AuthError` on 401/403 (stale cookie).
- `SubstackSyncConfig` — singleton holding the `substack.sid` cookie. Set per environment:
  `SubstackSyncConfig.instance.update!(session_cookie: "<value>")`.
- `Substack::NoteParser` — URL↔comment-id, ProseMirror↔plaintext, append/strip the post
  URL, build a doc from text, parse human timestamps.
- `Substack::Blizzard::DueFinder` — entries whose most-recent note is older than N days
  (or never posted), **most-stale-first**.
- `Substack::Blizzard::Backfiller` — builds `blizzard` from `notes` URLs (reads each note).
- `Substack::Blizzard::Reseeder` — replaces one entry's `body_json` from a real note.
- `Substack::Blizzard::RemoteReposter` — **runs on your Mac**: pulls due groups from prod,
  creates Notes (residential IP), records them back on prod.

Prod JSON API (admin basic-auth, used by the Mac task):
`GET /admin/substack-blizzard/due.json` and `POST /admin/substack-blizzard/add-note.json`.

## Authentication / the cookie

Get `substack.sid` from a logged-in browser: DevTools → Application → Cookies →
`https://substack.com` → `substack.sid` (it's HttpOnly, so the Console can't read it).

Set it where the work runs:

```bash
# locally (for reposting from your Mac)
SID='s%3A…' bin/rails runner 'SubstackSyncConfig.instance.update!(session_cookie: ENV["SID"])'

# on prod (for backfill / re-seed / admin UI reads)
ssh noob@<prod> 'export PATH=$HOME/.rbenv/shims:$PATH; cd /home/noob/blog/current && \
  SID="s%3A…" RAILS_ENV=production bundle exec rails runner \
  "SubstackSyncConfig.instance.update!(session_cookie: ENV[\"SID\"])"'
```

If the cookie expires you get a clear `AuthError` (admin flash, or task failure); just
re-run the relevant command with a fresh value.

## Workflows

### 1. Repost due groups (the main loop) — run on your Mac

Server-side posting is Cloudflare-blocked, so this runs locally from `~/Work/blog`:

```bash
DAYS=30 LIMIT=5 bin/rails substack:blizzard:repost_dry_run   # preview; no Notes created
DAYS=30 LIMIT=5 bin/rails substack:blizzard:repost           # post for real
```

- `DAYS` = staleness window (default 30). `LIMIT` = max **posts** per run.
- For each due group it: creates a link **attachment** (the post preview card), strips
  the inline post URL from the body (so it isn't duplicated), creates the Note, and
  POSTs the new `{url, timestamp}` back to prod.
- Skips entries with no `body_json` (would post an empty Note); these don't consume `LIMIT`.
- Paces ~5s between posts; retries transient errors.
- Order is **most-stale-first** (never-posted, then oldest).

Config via env (defaults shown): `BLIZZARD_PROD_URL=https://mikeyclarke.co.nz`,
`BLIZZARD_ADMIN_USER` / `BLIZZARD_ADMIN_PASS` (default: app admin creds).

Optional: schedule with a launchd agent on your Mac (runs only when the Mac is awake):

```xml
<!-- ~/Library/LaunchAgents/nz.co.mikeyclarke.blizzard-repost.plist -->
<dict>
  <key>Label</key><string>nz.co.mikeyclarke.blizzard-repost</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>-lc</string>
    <string>cd ~/Work/blog && DAYS=30 LIMIT=5 bin/rails substack:blizzard:repost >> /tmp/blizzard-repost.log 2>&1</string>
  </array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
</dict>
```
`launchctl load ~/Library/LaunchAgents/nz.co.mikeyclarke.blizzard-repost.plist`

### 2. Add an entirely new original Note

For new content promoting a post:

1. Compose the rich Note in Substack's editor (include the post's preview card), post it.
2. Add its URL to that post's Substack categorization `data["notes"]` (Post edit page →
   `#data` editor).
3. `RAILS_ENV=production … rake substack:blizzard:backfill` — original text → a new
   blizzard entry with rich `body_json` (read losslessly from the real note).
4. `… rake substack:blizzard:append_urls` — appends the trailing post URL to the new
   entry's `body_json` (idempotent).

Both tasks are idempotent: backfill skips notes already recorded; append_urls skips
already-linked entries. (Backfill iterates all Substack categorizations, ~3 min.)

### 3. Re-seed rich text into an existing entry

To upgrade a plain entry (e.g. one generated from text) to rich, or replace its content:
on `/admin/substack-blizzard`, paste a real Note URL into the entry's **Re-seed rich
text** field. The server reads that note and replaces the entry's `body_json` + `text`
(post URL appended). Only `body_json`/`text` change — the entry's `notes` history is
untouched. If the note has no readable body, it errors without wiping anything.

### 4. Manual paste-back (no Mac task)

On `/admin/substack-blizzard`, each entry has a **Copy** button (copies the text +
trailing post URL) and an **Add manually** form. Paste the text into Substack yourself,
then record the new Note's URL + timestamp (timestamp accepts Substack's footer format,
e.g. `21 Jun at 19:00`, interpreted as NZ time and stored UTC). Pasting a URL into
Substack's composer auto-creates the preview card, so the manual path keeps the inline
URL in the body (the automated path strips it and uses an attachment instead).

## Admin UI — `/admin/substack-blizzard`

- Linked from the Posts index ("Substack Blizzard" button).
- **Days** filter (1–60): show entries whose most-recent note is older than N days.
- Paginated 20/page, grouped under one heading per post, **most-stale-first**.
- Per entry: last-posted date, note count, the text (Copy button), **Add manually**,
  and **Re-seed rich text**. Page is retained after submitting a form.

## Rake tasks

| Task | Where | What |
|------|-------|------|
| `substack:blizzard:backfill[_dry_run]` | prod | Build `blizzard` from `notes` URLs (reads each note). |
| `substack:blizzard:append_urls[_dry_run]` | prod | Append the post URL to each entry's `body_json`. |
| `substack:blizzard:fill_missing_body_json[_dry_run]` | prod | Plain `body_json` from text for entries lacking it (lossy). |
| `substack:blizzard:repost[_dry_run]` | **Mac** | Create Notes for due groups; record back on prod. |
| `substack:blizzard:proof` | either | Round-trip test: post a throwaway Note (bold/italic/link), read back, delete. |

`_dry_run` variants write nothing. All writing tasks are idempotent.

## body_json and the post URL

The stored `body_json` ends with the post URL as an **inline link paragraph**
(`append_urls`). This is correct for the manual/copy path (pasting the URL into Substack
makes a card). The automated repost path **strips** that inline URL and re-adds the post
as a **card attachment** (`attachmentIds`) — matching how Substack's own UI renders a
pasted link.

Rich formatting only survives if it was captured from a real Note (backfill / re-seed).
`fill_missing_body_json` and `NoteParser.text_to_body_json` are last-resort fallbacks
that produce **plain** paragraphs — they cannot recover formatting that plaintext lost.

## Troubleshooting

- **`AuthError` / "session cookie (403)"** — cookie expired (or, for *posting* from prod,
  the Cloudflare block). Refresh the cookie in the right environment.
- **`Substack API 429 / 502`** — rate-limited / transient; the client retries with backoff.
  Reduce `LIMIT` if persistent.
- **Entry "SKIPPED (no body_json)"** on repost — re-seed it from a real note, or run
  `fill_missing_body_json` to give it plain content.
- **Reposted Note shows a truncated text link, not a preview card** — the body still has
  the inline URL; ensure you're on the attachment-based repost path (current code).
