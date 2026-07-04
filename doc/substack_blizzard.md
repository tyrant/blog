# Substack Blizzard

Track the rich-text content of Substack Notes as reusable assets, forecast when to
re-post them, and re-post that content as fresh Notes over time — keeping a history
of every repost. Admin at **`/admin/substack-blizzard`**.

## Concept

Each blog post has a Substack `Comfy::Cms::Categorization`. Its `#data` (jsonb) holds:

```jsonc
{
  "url":  "https://mikeyclarke.substack.com/p/…",        // canonical post URL
  "notes": [ "https://substack.com/…/note/c-…", … ],       // legacy flat URL list (retained)
  "blizzard": [
    {
      "text":      "<plaintext — used for matching + display>",
      "body_json": { "type": "doc", "attrs": {…}, "content": [ … ] }, // ProseMirror, lossless
      "notes":     [ { "url": "https://substack.com/…/note/c-…", "timestamp": "2025-08-…Z" }, … ]
    }
  ]
}
```

A **blizzard entry** ("group") is one piece of text-content plus every Note that has
posted it. `body_json` is the master copy used for reposting — it preserves bold /
italic / links as ProseMirror marks. `text` is its plaintext rendering. A group is
identified by **`(categorization_id, entry_index)`** — its position in the `blizzard`
array. A group's **anchor** is its most-recent note timestamp.

`#data["notes"]` is the old flat list, kept for now; prune later (like `#scratchpad`).

### The saved forecast — `BlizzardScheduleConfig`

A singleton row (`schedule` jsonb) holds the committed repost plan:

```jsonc
{
  "days": 7, "even": true, "shuffle": false,      // the controls that generated it
  "groupsDigest": "<hash of every (c,i,anchor)>",  // to detect the plan going stale
  "events": [
    { "c": 123, "i": 0, "t": "2026-07-10T09:00:00.000Z",
      "claimed_at": "…", "posted_at": "…" },       // lifecycle stamps (see Posting)
    …
  ]
}
```

Each event = "post group `(c,i)` at time `t`". `claimed_at`/`posted_at` track the
two-phase posting lifecycle.

## The Cloudflare constraint (read this first)

Substack's internal API is reached with a stored `substack.sid` session cookie.

- **Reads work from anywhere**, including the production DigitalOcean server.
- **Note-creation POSTs are blocked by Cloudflare from the datacenter IP** — they 403.
  The identical request succeeds from a **residential IP**.

So: backfilling, re-seeding, and the admin UI run server-side on prod, but **creating
new Notes (posting the schedule) runs from your Mac** via a local cron.

## Components

- `Substack::Client` — internal-API wrapper (cookie auth). `get_note`, `create_note`,
  `create_attachment`, `delete_note`. Retries 429/502/503/504; raises `AuthError` on
  401/403 (stale cookie). Cookie comes from `SubstackSyncConfig.instance` in **the DB
  of wherever it runs** (local DB for posting, prod DB for reads).
- `SubstackSyncConfig` — singleton holding the `substack.sid` cookie.
- `Substack::NoteParser` — URL↔comment-id, ProseMirror↔plaintext, append/strip the
  post URL, build a doc from text, parse human timestamps.
- `Substack::Blizzard::ForecastData` — every group across all Substack categorizations
  with its `{categorizationId, entryIndex, anchor, title, content, url, editUrl}`.
  Seeded into the calendar as a one-off JSON payload (camelCase — consumed directly by
  the TS controller).
- `Substack::Blizzard::DueFinder` — entries whose most-recent note is older than N days
  (backs the admin due-list view only).
- `Substack::Blizzard::Backfiller` — builds `blizzard` from `notes` URLs. **Additive and
  index-stable** (appends new groups, never reorders/removes).
- `Substack::Blizzard::Reseeder` — replaces one entry's `body_json` from a real note.
- `Substack::Blizzard::ScheduleClaimer` / `ScheduleConfirmer` — the prod side of
  schedule-driven posting (claim due events / record a posted one), under a row lock.
- `Substack::Blizzard::ScheduledReposter` — **runs on your Mac**: claims due events from
  prod, creates Notes (residential IP), confirms them back.
- `BackfillAllJob` / `BackfillPostJob` — SolidQueue jobs (see
  [solid_queue.md](solid_queue.md)).

## Authentication / the cookie

Get `substack.sid` from a logged-in browser: DevTools → Application → Cookies →
`https://substack.com` → `substack.sid` (HttpOnly, so the Console can't read it).

```bash
# locally (posting runs from your Mac, so the LOCAL DB's cookie is what posts)
SID='s%3A…' bin/rails runner 'SubstackSyncConfig.instance.update!(session_cookie: ENV["SID"])'

# on prod (backfill / re-seed reads)
ssh noob@<prod> 'cd ~/blog/current && SID="s%3A…" RAILS_ENV=production \
  ~/.rbenv/bin/rbenv exec bundle exec rails runner \
  "SubstackSyncConfig.instance.update!(session_cookie: ENV[\"SID\"])"'
```

If the cookie expires you get a clear `AuthError` (admin flash, or the local task's
FAILED line); re-run with a fresh value in the right environment.

## The admin page

### Repost forecast calendar

A FullCalendar month view (client-side, `blizzard_forecast_controller.ts` +
pure `blizzard_forecast.ts`) that plots each group's upcoming reposts over a **90-day
horizon**. Everything recomputes in-browser — the groups are a one-off JSON payload,
**no AJAX** on any control change.

- **Repost every (days)** (default 7): the repost interval. Each group recurs every N
  days from its anchor; overdue/never-posted groups collapse onto today.
- **Evenly spread reposts across the interval** (default on): ignore anchors and
  distribute every group evenly across `[now, now+N days]`, then recur every N — flattens
  the anchor-driven bunching.
- **Spread same-post reposts across each day** (default off): reorder each day's reposts
  so each Post's reposts sit at even fractional positions (its `k` reposts ~`1/k` apart,
  randomly rotated) — same-Post reposts are non-adjacent whenever a Post is ≤ half that
  day's reposts. (Internally still the `shuffle` field.)
- **Save Forecasts**: POSTs the concrete arrangement to `BlizzardScheduleConfig`. Load
  renders the *saved* schedule verbatim (so ordering persists across reloads/devices);
  the status shows **Forecasts saved / Unsaved forecasts**, or an amber **"out of date —
  re-save"** when a `groupsDigest` mismatch means a backfill/repost changed the groups.
- Per day: a **pastel tint** by interval block, an **"X entries"** count by the day
  number, a scrollable event list, a **hover tooltip** (post-title link → Post#edit,
  Note text, timestamp), and a **day-number popover** listing that day's reposts.

### Due list, re-seed, manual paste-back

Below the calendar, `DueFinder` lists groups whose most-recent note is older than the
**Days** filter (1–60), most-stale-first, 20/page. Per entry: a **Copy** button, an
**Add manually** form (record a Note you posted by hand — timestamp accepts Substack's
`21 Jun at 19:00` footer format, stored UTC), and **Re-seed rich text** (paste a real
Note URL to replace that entry's `body_json`/`text`; history untouched).

> The old server-side **"Create note now"** button uses `Reposter` on prod and is
> **Cloudflare-blocked** — it can't actually post. Posting goes through the schedule.

### Backfill buttons

- **"Backfill all posts' notes"** (top of the page) → `BackfillAllJob`.
- **"Backfill this post's notes"** (CMS Post editor sidebar) → `BackfillPostJob`.

Both enqueue SolidQueue jobs (run on the prod worker; Substack reads are allowed there)
and flash immediately. Backfill is additive/idempotent, so re-clicking is safe.

## Forecast → schedule → posting

1. **Forecast** (browser): from the groups payload + controls, compute concrete events
   `{c,i,t}` over 90 days. Save commits them to `BlizzardScheduleConfig` (with a
   `groupsDigest` snapshot of the groups' anchors).
2. **Posting** (your Mac, every 15 min via cron): claims due events from prod, posts
   each as a Note, confirms back. **Two-phase** so a crashed run's claims self-heal.

The local cron (residential IP):

```cron
*/15 * * * * cd /Users/you/Work/blog && PATH="$HOME/.rbenv/shims:/opt/homebrew/bin:/usr/bin:/bin" bin/rails substack:blizzard:post_scheduled >> /tmp/blizzard_post.log 2>&1
```

- `substack:blizzard:post_scheduled` → `ScheduledReposter` → `POST /scheduled/claim.json`
  (prod selects `posted_at`-nil, `t ≤ now`, unclaimed-or-stale events **oldest-first,
  capped at `LIMIT`** (default 5), stamps `claimed_at`, returns them hydrated with
  `body_json`) → create the Note (attachment card + inline URL stripped) → `POST
  /scheduled/confirm.json` (append the note to the group + set `posted_at`, idempotent).
- Stale claims (`claimed_at` older than **`CLAIM_TIMEOUT`**, default 30 min) are
  reclaimed — so a crash between claim and confirm reposts, rather than losing the event.
  Selection is serialised under a DB row lock on the singleton.
- Env: `BLIZZARD_PROD_URL` (default `https://mikeyclarke.co.nz`), `BLIZZARD_ADMIN_USER` /
  `BLIZZARD_ADMIN_PASS` (default: app admin creds), `LIMIT`.
- `substack:blizzard:post_scheduled_dry_run` previews via `GET /scheduled-due.json`
  (read-only, no claim). Both talk to **prod** by default — the local Mac only provides
  its IP + Substack cookie + admin creds.
- On macOS, `flock` isn't installed and isn't needed (the prod claim lock prevents
  double-posting); give `cron` **Full Disk Access** or it silently won't run.

### Staleness / re-saving

The saved schedule is a **fixed 90-day snapshot**. Two ways it ages:

- **`groupsDigest` (the banner):** a hash of every `(c,i,anchor)`. It changes when an
  anchor moves — and **every posted repost appends a note, moving that group's anchor**
  (backfills/manual notes too). So as the cron posts, the digest diverges → the amber
  "out of date — re-save" banner appears. It's not time alone; it's the posting activity.
- **The horizon:** the future tail is fixed at save-time + 90 days and doesn't extend
  itself. Once all events are posted/past, reposting quietly stops until a re-save.

**Re-saving** both refreshes anchors (a just-posted group's next repost recomputes from
its new time — no over-posting) and slides the horizon forward. Re-save periodically
(the banner is your cue). There's no automatic re-forecasting.

## Adding a new original Note

1. Compose the rich Note in Substack's editor (include the post's preview card), post it.
2. Add its URL to that post's `data["notes"]` (Post edit `#data` editor).
3. **Backfill this post** (button) — original text → a new blizzard entry with lossless
   `body_json`.
4. Re-save the forecast (the banner will be showing) to fold the new group in.

## Rake tasks

| Task | Where | What |
|------|-------|------|
| `substack:blizzard:post_scheduled[_dry_run]` | **Mac** | Post due scheduled reposts; confirm back on prod. |
| `substack:blizzard:backfill[_dry_run]` | prod | Build `blizzard` from `notes` URLs (also via the buttons). |
| `substack:blizzard:append_urls[_dry_run]` | prod | Append the post URL to each entry's `body_json`. |
| `substack:blizzard:fill_missing_body_json[_dry_run]` | prod | Plain `body_json` from text for entries lacking it (lossy). |
| `substack:blizzard:proof` | either | Round-trip test: post a throwaway Note, read back, delete. |

`_dry_run` variants write nothing. All writing tasks are idempotent. (The old
`repost`/`RemoteReposter`/`due.json` path is retired in favour of schedule-driven posting.)

## body_json and the post URL

The stored `body_json` ends with the post URL as an **inline link paragraph**
(`append_urls`) — correct for the manual/copy path (pasting the URL into Substack makes a
card). The automated posting path **strips** that inline URL and re-adds the post as a
**card attachment** (`attachmentIds`), matching Substack's own UI.

Rich formatting only survives if captured from a real Note (backfill / re-seed).
`fill_missing_body_json` is a last-resort fallback producing **plain** paragraphs.

## Troubleshooting

- **`AuthError` / FAILED on `post_scheduled`** — the **local** Substack cookie is stale
  (posting uses the local DB's cookie); refresh it locally. Prod claim/confirm still work.
- **Cron never runs (empty `/tmp/blizzard_post.log`)** — give `/usr/sbin/cron` Full Disk
  Access; note cron doesn't fire while the Mac is asleep (the backlog drains later).
- **Calendar shows "out of date" / all same title on load** — the first is expected (see
  Staleness); re-save. (The second was a fixed camelCase-key bug.)
- **Backfill/emails not happening** — the SolidQueue worker is down; see
  [solid_queue.md](solid_queue.md).
- **Entry skipped "no body_json"** — re-seed it from a real note, or `fill_missing_body_json`.
