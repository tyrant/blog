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

A third pool — **unattached Notes**, with no parent Post or Quotation — lives in the
same shape on `BlizzardScheduleConfig#data` (a jsonb column, edited as JSON text in
the admin's "Unattached Notes" section): paste Note URLs into its `"notes"` key,
Backfill turns them into tracked `"blizzard"` entries exactly as above. `Backfiller`
and `LikesRefresher` accept either a Substack categorization or the
`BlizzardScheduleConfig` singleton (both expose `#data`/`#update!(data:)`); the
singleton has no `#url`/parent post, so the mislink check and post-likes refresh
no-op for it.

### Settings — `BlizzardScheduleConfig`

A singleton row holds the reposting settings:

- `interval_minutes` (default 30) — minutes between reposts.
- `cooldown_hours` (default 12) — a post rests this long after any of its entries is
  reposted; while resting, none of that post's entries are eligible.
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
  lock, if `interval_minutes` has elapsed, it rolls one random number against three
  cumulative bands — `QUOTATION_ODDS` (24%) hands back a **random featured quotation**
  built into a Note; the next `UNATTACHED_ODDS` (2%) weighted-samples one eligible
  **unattached** entry (`Substack::Blizzard::UnattachedOdds`); the remaining 74% weighted-
  samples one eligible **per-post** text entry (`RepostOdds`; weight = 1 + Σ note likes +
  post likes; excludes entries whose post is in cooldown or lacking `body_json`). An empty
  tier falls through to the next one. Either way it stamps `last_reposted_at` and returns
  the pick hydrated. `dry_run` previews without claiming.
- `Substack::Blizzard::UnattachedOdds` — the unattached-pool equivalent of `RepostOdds`:
  candidates from `BlizzardScheduleConfig#data["blizzard"]`, weight = 1 + Σ note likes (no
  post-likes term — no parent post). Cooldown rests each entry **individually** (there's no
  post to bench as a group), using the same `cooldown_hours` setting.
- `Substack::Blizzard::QuotationNote` — builds a Note `body_json` from a `SubstackQuotation`
  in the **Note** ProseMirror schema (blockquote + bold/italic/link marks; Notes have no
  heading or paragraph alignment): a bold post-title link, the italic quote trailed by a 🔗
  to the original comment, the linked author, and a **"More at the Reviews Page (`<url>`)"**
  line — mirroring the post-footer syncQuotations template. The post rides along as a card
  attachment (added by the ticker). **Reviews-link gotcha:** the reviews-page URL is emitted
  as **plain text, unmarked** — an explicit `link` mark to that URL gets **stripped on
  publish** (it's a `type:"page"`, not a card-able post; stripped even with descriptive anchor
  text), whereas a **bare URL in plain text is auto-linkified and kept** by Substack. Don't
  re-wrap it in a link mark. (The post-title/comment/author links survive because they sit on
  non-URL anchor text.)
- `Substack::Blizzard::QuotationPreviewer` — **runs on your Mac**: posts a real quotation Note
  so its live Substack rendering can be eyeballed before it fires for real, then hands back its
  id/url to delete. Fetches the built note from prod
  (`GET /admin/substack-blizzard/quotation/preview.json`, random or `?id=`, nothing claimed),
  posts note + post-card attachment via `Substack::Client`. Driven by the
  `substack:blizzard:preview_quotation` task (below) — the only faithful way to catch
  Substack-side rendering surprises (like the reviews-link stripping) before they go live.
- `Substack::Blizzard::RepostRecorder` — records a completed repost (append
  `{url, timestamp, likes: 0}` to the entry by `uid`, idempotent by url). A blank
  `categorization_id` targets `BlizzardScheduleConfig` instead of a categorization — the
  unattached pool.
- `Substack::Blizzard::RepostTicker` — **runs on your Mac**: asks prod for the next
  weighted repost, creates the Note (residential IP), confirms it back. Confirms whenever
  `categorization_id` OR `uid` is present — a quotation pick has neither (untracked); an
  unattached pick has `uid` but no `categorization_id` (tracked against
  `BlizzardScheduleConfig`).
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

A small form sets **Repost every (minutes)** and **Per-post cooldown (hours)** (POSTs to
`#update_settings`), and shows when the last repost fired. That's the whole control
surface — selection is automatic (74% weighted per-post text group, 24% random quotation,
2% weighted unattached note); there's no schedule to arrange. The shares are the
`QUOTATION_ODDS`/`UNATTACHED_ODDS` constants, not form fields.

### Unattached Notes

A JSON textarea editing `BlizzardScheduleConfig#data` directly (paste Note URLs into its
`"notes"` key, save), a **Backfill unattached Notes** button (`BackfillUnattachedNotesJob`),
and that's it — no due-list/add-manually/re-seed tooling for this pool (small enough, and
edited by hand). Tracked entries accumulate under `"blizzard"` in the same textarea once
backfilled.

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
- **"Backfill unattached Notes"** → `BackfillUnattachedNotesJob` (the third pool, above).
- **"Refresh all Note/Post likes"** → `RefreshNotePostLikesJob` (an immediate run of the
  daily job; also refreshes the unattached pool's note likes).
- **"Backfill this post's notes"** (CMS Post editor sidebar) → `BackfillPostJob`.

All enqueue SolidQueue jobs (run on the prod worker; Substack reads are allowed there) and
flash immediately. All are additive/idempotent, so re-clicking is safe.

## How reposting works

1. **Likes** (prod, daily 4am): `RefreshNotePostLikesJob` re-reads every note's
   `reaction_count` into its `likes`, and each post's `reaction_count` into the post's
   `substack_likes`. This is the popularity signal.
2. **Tick** (your Mac, every ~2 min via cron): asks prod for the next repost. Prod
   (`WeightedPicker`) gates itself to one pick per `interval_minutes`, so most ticks are
   no-ops. When it's time, it hands back either a text entry or a quotation (see below); the
   Mac posts it and confirms back. **Two-phase** (claim by stamping `last_reposted_at`,
   then confirm by appending the note) under a DB row lock, so overlapping ticks can't
   double-fire.

**Text vs. quotation vs. unattached (74 / 24 / 2):** on each due pick, `WeightedPicker`
rolls one random number against three cumulative bands: `[0, QUOTATION_ODDS)` (0.24) →
a random `SubstackQuotation` ([the Quotations pool](substack_post_sync.md#quotations))
built into a Note by `QuotationNote` and posted with the post as a card attachment;
`[QUOTATION_ODDS, QUOTATION_ODDS + UNATTACHED_ODDS)` (0.02) → the weighted unattached pick
below; the remaining `[0.26, 1)` (0.74) → the weighted per-post text pick below. An empty
tier falls through to the next one (quotation → unattached → text). Quotation reposts are
**not tracked** (no `categorization_id`/`uid`), so the ticker skips the confirm/
`RepostRecorder` step and the admin odds leaderboard reflects only the 74% per-post text
share. Unattached reposts **are** tracked (`uid` set, `categorization_id` blank —
`RepostRecorder` targets `BlizzardScheduleConfig` instead of a categorization).

**Weighting (per-post 74% and unattached 2%):** an entry's pick probability ∝
`1 + Σ(its notes' likes)`, plus its post's likes for the per-post pool (no such term for
unattached — no parent post). The `+1` base gives never-posted / zero-like entries a small
chance; the sums make heavily-liked entries (and popular posts — a post's likes lift every
one of its entries — and, deliberately, entries reposted often) win more. Entries with no
`body_json` are excluded; so are entries in cooldown — as a whole **post** (all its
entries) for the per-post pool, or **individually** for the unattached pool (no post to
bench as a group) — both against the same `cooldown_hours` setting.

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
| `substack:blizzard:preview_quotation` | **Mac** | Post a quotation Note to eyeball its Substack rendering, then delete on a `[Y/n]` prompt. `QUOTATION_ID=<id>` pins one. |
| `substack:blizzard:backfill[_dry_run]` | prod | Build `blizzard` from `notes` URLs (also via the buttons). |
| `substack:blizzard:append_urls[_dry_run]` | prod | Append the post URL to each entry's `body_json`. |
| `substack:blizzard:fill_missing_body_json[_dry_run]` | prod | Plain `body_json` from text for entries lacking it (lossy). |
| `substack:blizzard:proof` | either | Round-trip test: post a throwaway Note, read back, delete. |

`_dry_run` variants write nothing. All writing tasks are idempotent.

`preview_quotation` **must be run interactively** (a real terminal): it posts the Note live,
prints its URL, and waits at a `[Y/n]` delete prompt so you can open it first. Run
non-interactively (stdin not a TTY) it reads empty and **auto-deletes** before you can look.
The Note is briefly public in the meantime (Notes don't send email, so no subscriber blast).

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
  every tick returns `{}` if it's not yet time or every post is in cooldown / every entry
  lacks `body_json`.
- **Likes all zero / stale** — the daily `RefreshNotePostLikesJob` hasn't run (SolidQueue
  worker down; see [solid_queue.md](solid_queue.md)); hit "Refresh all Note/Post likes" to
  force it.
- **Entry never picked** — its post may be permanently in cooldown (any of the post's
  entries has a very recent note), or the entry lacks `body_json` (re-seed it, or
  `fill_missing_body_json`).
