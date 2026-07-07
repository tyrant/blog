# Substack Blizzard

Track the rich-text content of Substack Notes as reusable assets and re-post that
content as fresh Notes over time — **popularity-weighted**, so well-liked content
reposts more often — keeping a history (and like-count) of every repost. Admin at
**`/admin/substack-blizzard`**.

## Concept

Each blog post has a Substack `Comfy::Cms::Categorization`. Its `#data` (jsonb) holds:

```jsonc
{
  "url":  "https://mikeyclarke.substack.com/p/…",        // canonical post URL
  "notes": [ "https://substack.com/…/note/c-…", … ],       // legacy flat URL list (retained)
  "blizzard": [
    {
      "uid":       "b1f0…",                                 // stable per-entry id
      "text":      "<plaintext — used for matching + display>",
      "body_json": { "type": "doc", "attrs": {…}, "content": [ … ] }, // ProseMirror, lossless
      "notes":     [ { "url": "…/note/c-…", "timestamp": "2025-08-…Z", "likes": 9 }, … ]
    }
  ]
}
```

A **blizzard entry** ("group") is one piece of text-content plus every Note that has
posted it. `body_json` is the master copy used for reposting — it preserves bold /
italic / links as ProseMirror marks. `text` is its plaintext rendering. An entry is
identified by its **`uid`** (stable across reordering/deletion). Each note records its
Substack **`likes`** (the ❤ `reaction_count`), refreshed daily; the post's own like count
lives on the post (`comfy_blog_posts.substack_likes`), refreshed by the same job.

`#data["notes"]` is the old flat list, kept for now; prune later (like `#scratchpad`).

### Settings — `BlizzardScheduleConfig`

A singleton row holds the reposting settings:

- `interval_minutes` (default 30) — minutes between reposts.
- `cooldown_hours` (default 12) — an entry rests this long after any repost before it's
  eligible again.
- `last_reposted_at` — the claim clock; stamped each time a repost is handed out.

(The legacy `schedule` jsonb column — the removed forecast calendar's saved arrangement
— is retired but not yet dropped.)

## The Cloudflare constraint (read this first)

Substack's internal API is reached with a stored `substack.sid` session cookie.

- **Reads work from anywhere**, including the production DigitalOcean server.
- **Note-creation POSTs are blocked by Cloudflare from the datacenter IP** — they 403.
  The identical request succeeds from a **residential IP**.

So: backfilling, likes-refresh, weighted selection, and the admin UI run server-side on
prod, but **creating new Notes runs from your Mac** via a local cron.

## Components

- `Substack::Client` — internal-API wrapper (cookie auth). `get_note`, `create_note`,
  `create_attachment`, `delete_note`. Retries 429/502/503/504; raises `AuthError` on
  401/403 (stale cookie). Cookie comes from `SubstackSyncConfig.instance` in **the DB
  of wherever it runs** (local DB for posting, prod DB for reads).
- `SubstackSyncConfig` — singleton holding the `substack.sid` cookie.
- `Substack::NoteParser` — URL↔comment-id, ProseMirror↔plaintext, append/strip the
  post URL, build a doc from text, parse human timestamps, **`likes`** (`reaction_count`).
- `Substack::Blizzard::DueFinder` — entries whose most-recent note is older than N days
  (backs the admin due-list view / manual tools only).
- `Substack::Blizzard::Backfiller` — builds `blizzard` from `notes` URLs. Additive and
  idempotent; mints a `uid` for each new entry.
- `Substack::Blizzard::LikesRefresher` — re-fetches every note of one categorization and
  writes its `likes`; a failed fetch keeps the last-known value.
- `Substack::Blizzard::Reseeder` — replaces one entry's `body_json` from a real note.
- `Substack::Blizzard::WeightedPicker` — the prod side of reposting: under the config row
  lock, if `interval_minutes` has elapsed, weighted-samples one eligible entry
  (weight = 1 + Σ note likes; excludes entries in cooldown or lacking `body_json`),
  stamps `last_reposted_at`, and returns it hydrated. `dry_run` previews without claiming.
- `Substack::Blizzard::RepostRecorder` — records a completed repost (append
  `{url, timestamp, likes: 0}` to the entry by `uid`, idempotent by url).
- `Substack::Blizzard::RepostTicker` — **runs on your Mac**: asks prod for the next
  weighted repost, creates the Note (residential IP), confirms it back.
- `RefreshNotePostLikesJob` — daily SolidQueue job; walks every Substack categorization on
  the prod worker and refreshes both note likes and each post's likes. `BackfillAllJob` /
  `BackfillPostJob` — backfill jobs. See
  [refresh_note_post_likes_job.md](refresh_note_post_likes_job.md) and
  [solid_queue.md](solid_queue.md).

## Authentication / the cookie

Get `substack.sid` from a logged-in browser: DevTools → Application → Cookies →
`https://substack.com` → `substack.sid` (HttpOnly, so the Console can't read it).

```bash
# locally (posting runs from your Mac, so the LOCAL DB's cookie is what posts)
SID='s%3A…' bin/rails runner 'SubstackSyncConfig.instance.update!(session_cookie: ENV["SID"])'

# on prod (backfill / likes / re-seed reads)
ssh noob@<prod> 'cd ~/blog/current && SID="s%3A…" RAILS_ENV=production \
  ~/.rbenv/bin/rbenv exec bundle exec rails runner \
  "SubstackSyncConfig.instance.update!(session_cookie: ENV[\"SID\"])"'
```

If the cookie expires you get a clear `AuthError` (admin flash, or the local task's
FAILED line); re-run with a fresh value in the right environment.

## The admin page

### Automated reposting (settings)

A small form sets **Repost every (minutes)** and **Per-entry cooldown (hours)** (POSTs to
`#update_settings`), and shows when the last repost fired. That's the whole control
surface — selection is automatic and weighted; there's no schedule to arrange.

### Due list, re-seed, manual paste-back

`DueFinder` lists entries whose most-recent note is older than the **Days** filter (1–60),
most-stale-first, 20/page. Per entry: a **Copy** button, an **Add manually** form (record
a Note you posted by hand — timestamp accepts Substack's `21 Jun at 19:00` footer format,
stored UTC), and **Re-seed rich text** (paste a real Note URL to replace that entry's
`body_json`/`text`; history untouched). These are manual tools, independent of the
automated reposter.

> The server-side **"Create note now"** button uses `Reposter` on prod and is
> **Cloudflare-blocked** — it can't actually post. Automated posting runs from your Mac.

### Backfill / likes buttons

- **"Backfill all posts' notes"** → `BackfillAllJob`.
- **"Refresh all Note/Post likes"** → `RefreshNotePostLikesJob` (an immediate run of the daily job).
- **"Backfill this post's notes"** (CMS Post editor sidebar) → `BackfillPostJob`.

All enqueue SolidQueue jobs (run on the prod worker; Substack reads are allowed there) and
flash immediately. All are additive/idempotent, so re-clicking is safe.

## How reposting works

1. **Likes** (prod, daily 4am): `RefreshNotePostLikesJob` re-reads every note's
   `reaction_count` into its `likes`, and each post's `reaction_count` into the post's
   `substack_likes`. This is the popularity signal.
2. **Tick** (your Mac, every ~2 min via cron): asks prod for the next repost. Prod
   (`WeightedPicker`) gates itself to one pick per `interval_minutes`, so most ticks are
   no-ops. When it's time, it weighted-samples one eligible entry and hands it back; the
   Mac posts it and confirms back. **Two-phase** (claim by stamping `last_reposted_at`,
   then confirm by appending the note) under a DB row lock, so overlapping ticks can't
   double-fire.

**Weighting:** an entry's pick probability ∝ `1 + Σ(its notes' likes) + its post's likes`.
The `+1` base gives never-posted / zero-like entries a small chance; the sums make
heavily-liked entries (and popular posts — a post's likes lift every one of its entries —
and, deliberately, entries reposted often) win more. Entries reposted within
`cooldown_hours`, or with no `body_json`, are excluded.

The local cron (residential IP):

```cron
*/2 * * * * cd /Users/you/Work/blog && PATH="$HOME/.rbenv/shims:/opt/homebrew/bin:/usr/bin:/bin" bin/rails substack:blizzard:tick >> /tmp/blizzard_post.log 2>&1
```

- `substack:blizzard:tick` → `RepostTicker` → `POST /repost/tick.json` (prod claims one
  weighted entry, or returns `{}` when not yet due / nothing eligible) → create the Note
  (attachment card + inline URL stripped) → `POST /repost/confirm.json` (append the note,
  idempotent by url).
- `substack:blizzard:tick_dry_run` previews via `GET /repost/preview.json` (read-only, no
  claim). Both talk to **prod** by default — the local Mac only provides its IP + Substack
  cookie + admin creds.
- Env: `BLIZZARD_PROD_URL` (default `https://mikeyclarke.co.nz`), `BLIZZARD_ADMIN_USER` /
  `BLIZZARD_ADMIN_PASS` (default: app admin creds).
- On macOS, give `cron` **Full Disk Access** or it silently won't run; cron doesn't fire
  while the Mac is asleep (no reposts happen then — harmless).

## Adding a new original Note

1. Compose the rich Note in Substack's editor (include the post's preview card), post it.
2. Add its URL to that post's `data["notes"]` (Post edit `#data` editor).
3. **Backfill this post** (button) — original text → a new blizzard entry (with a `uid`)
   with lossless `body_json`. It enters the weighted pool automatically.

## Rake tasks

| Task | Where | What |
|------|-------|------|
| `substack:blizzard:tick[_dry_run]` | **Mac** | Post the next weighted repost; confirm back on prod. |
| `substack:blizzard:backfill[_dry_run]` | prod | Build `blizzard` from `notes` URLs (also via the buttons). |
| `substack:blizzard:append_urls[_dry_run]` | prod | Append the post URL to each entry's `body_json`. |
| `substack:blizzard:fill_missing_body_json[_dry_run]` | prod | Plain `body_json` from text for entries lacking it (lossy). |
| `substack:blizzard:proof` | either | Round-trip test: post a throwaway Note, read back, delete. |

`_dry_run` variants write nothing. All writing tasks are idempotent.

## body_json and the post URL

The stored `body_json` ends with the post URL as an **inline link paragraph**
(`append_urls`) — correct for the manual/copy path (pasting the URL into Substack makes a
card). The automated posting path **strips** that inline URL and re-adds the post as a
**card attachment** (`attachmentIds`), matching Substack's own UI.

Rich formatting only survives if captured from a real Note (backfill / re-seed).
`fill_missing_body_json` is a last-resort fallback producing **plain** paragraphs.

## Troubleshooting

- **`AuthError` / FAILED on `tick`** — the **local** Substack cookie is stale (posting uses
  the local DB's cookie); refresh it locally. Prod tick/confirm still work.
- **Cron never runs (empty `/tmp/blizzard_post.log`)** — give `/usr/sbin/cron` Full Disk
  Access; note cron doesn't fire while the Mac is asleep.
- **Nothing ever reposts** — check `last_reposted_at` is advancing and `interval_minutes`;
  every tick returns `{}` if it's not yet time or every entry is in cooldown / lacks
  `body_json`.
- **Likes all zero / stale** — the daily `RefreshNotePostLikesJob` hasn't run (SolidQueue
  worker down; see [solid_queue.md](solid_queue.md)); hit "Refresh all Note/Post likes" to
  force it.
- **Entry never picked** — it may be permanently in cooldown (a very recent note) or lack
  `body_json` (re-seed it, or `fill_missing_body_json`).
