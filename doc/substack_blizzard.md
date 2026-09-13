# Substack Blizzard

Track the rich-text content of Substack Notes as reusable assets and re-post that
content as fresh Notes over time — **popularity-weighted**, so well-liked content
surfaces more often — keeping a history (and like-count) of every repost. Posting a
Note is always a manual, hands-on step (see "The Cloudflare constraint" below); this
feature picks *what* to suggest reposting next and gets it copy-paste-ready with full
rich formatting. Admin at **`/admin/substack-blizzard`**.

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
      "post_url":  "https://…/p/…",                                  // the note's own preview-card attachment, if any (unattached pool only)
      "notes":     [ { "url": "…/note/c-…", "timestamp": "2025-08-…Z", "likes": 9 }, … ]
    }
  ]
}
```

A **blizzard entry** ("group") is one piece of text-content plus every Note that has
posted it. `body_json` is the master copy used for reposting — it preserves bold /
italic / links as ProseMirror marks, and ends with the entry's post as an inline link
paragraph (see "body_json and the post URL" below) so a copy-pasted repost always
references its source post. `text` is its plaintext rendering. An entry is identified
by its **`uid`** (stable across reordering/deletion). Each note records its Substack
**`likes`** (the ❤ `reaction_count`), refreshed daily; the post's own like count lives
on the post (`comfy_blog_posts.substack_likes`), refreshed by the same job.

`#data["notes"]` is the old flat list, kept for now; prune later (like `#scratchpad`).

A third pool — **unattached Notes**, with no parent Post or Quotation — lives in the
same shape on `BlizzardScheduleConfig#data` (a jsonb column, edited as JSON text in
the admin's "Unattached Notes" section): paste Note URLs into its `"notes"` key,
Backfill turns them into tracked `"blizzard"` entries exactly as above. `Backfiller`
and `LikesRefresher` accept either a Substack categorization or the
`BlizzardScheduleConfig` singleton (both expose `#data`/`#update!(data:)`); the
singleton has no `#url`/parent post, so the mislink check and post-likes refresh
no-op for it.

A fourth pool — **quotations** (`SubstackQuotation`, `/admin/quotations`) — is
featured-review content, not a blizzard entry at all, but reposts of it are tracked
the same way: a `notes` jsonb column directly on the quotation row (`{url, timestamp,
likes}`), via `QuotationRecorder`.

### Settings — `BlizzardScheduleConfig`

A singleton row holds the selection settings:

- `interval_minutes` (default 30) — minutes before a new suggestion becomes due again.
- `cooldown_hours` (default 12) — a post rests this long after any of its entries is
  reposted; while resting, none of that post's entries are eligible.
- `last_reposted_at` — the claim clock; stamped when a suggestion is claimed
  (non-`dry_run`). In practice only the retired automated path (see below) ever
  claimed non-dry-run, so this can go stale now that it's gone — see Troubleshooting.

(The legacy `schedule` jsonb column — the removed forecast calendar's saved arrangement
— is retired but not yet dropped.)

## The Cloudflare constraint (read this first)

Substack's internal API is reached with a stored `substack.sid` session cookie.

- **Reads work from anywhere** — the production DigitalOcean server, your Mac, either.
- **Note-creation POSTs are blocked for any automated client, full stop.** This was
  originally thought to be a datacenter-IP block (Cloudflare passing identical
  requests from a residential Mac), and an automated Mac-driven posting flow ran on
  that assumption for a while. Further testing disproved it: the same POST 403s from
  a real Playwright-driven Chromium too — headless or headful, via `page.request` or a
  genuine in-page `fetch()`, with a valid session cookie *and* a valid `cf_clearance`
  cookie, with headers and payload byte-matched to a real browser's. Nothing about the
  request differs from what actually works when a human clicks Post — what differs is
  that the browser is automation-driven at all (almost certainly a CDP/fingerprint
  signal), and that isn't spoofable from outside a real, human-operated browser.

So: **posting a Note is always a manual step now**, done by a human in their own
logged-in Substack tab. Everything in this app up to that point — selection,
formatting, rich-copy — runs server-side on prod; only the actual click to post
happens outside this app entirely.

## Components

- `Substack::Client` — internal-API wrapper (cookie auth). `get_note`,
  `create_attachment` are live (reads/attachment-creation aren't blocked). `create_note`
  still exists but nothing in the app calls it anymore — Note-creation is blocked
  regardless of caller (see above); it's retained as a thin wrapper method, not wired
  to anything.
- `SubstackSyncConfig` — singleton holding the `substack.sid` cookie. Only needed for
  reads now (backfill, likes-refresh, re-seed, and resolving a posted Note's real
  timestamp) — nothing posts through it anymore, so there's no separate "local cookie
  for posting" concern; one cookie, wherever the app runs (prod).
- `Substack::NoteParser` — URL↔comment-id, ProseMirror↔plaintext, append/strip the
  post URL, build a doc from text, **`likes`** (`reaction_count`), and **`to_html`** —
  renders a `body_json` doc to real HTML (bold/italic/link marks; blockquote/list
  nodes), put on the clipboard alongside the plain text so pasting into Substack's
  Note composer (a ProseMirror editor) keeps the formatting.
- `Substack::Blizzard::DueFinder` — entries whose most-recent note is older than N days
  (backs the admin due-list view / manual tools only).
- `Substack::Blizzard::Backfiller` — builds `blizzard` from `notes` URLs. Additive and
  idempotent; mints a `uid` for each new entry, capturing that note's own preview-card
  attachment (if any) as the entry's `post_url` (`NoteParser.attachment_post_url`).
- `Substack::Blizzard::LikesRefresher` — re-fetches every note of one categorization and
  writes its `likes`; a failed fetch keeps the last-known value.
- `Substack::Blizzard::Reseeder` — replaces one entry's `body_json` (and `post_url`, from the
  note's own attachment) from a real note.
- `Substack::Blizzard::WeightedPicker` — the selection logic behind the admin's "Next
  repost suggestion" panel: under the config row lock, if `interval_minutes` has
  elapsed, it rolls one random number against three cumulative bands —
  `QUOTATION_ODDS` (24%) hands back a **random featured quotation**; the next
  `UNATTACHED_ODDS` (2%) weighted-samples one eligible **unattached** entry
  (`Substack::Blizzard::UnattachedOdds`); the remaining 74% weighted-samples one
  eligible **per-post** text entry (`RepostOdds`; weight = 1 + Σ note likes + post
  likes; excludes entries whose post is in cooldown or lacking `body_json`). An empty
  tier falls through to the next one. `dry_run` (what the admin page always uses)
  previews without claiming; a non-dry-run claim stamps `last_reposted_at`, but
  nothing currently calls it that way — the `POST /repost/tick.json` endpoint it backs
  is still routed, just unused now that the local cron is gone.
- `Substack::Blizzard::UnattachedOdds` — the unattached-pool equivalent of `RepostOdds`:
  candidates from `BlizzardScheduleConfig#data["blizzard"]`, weight = 1 + Σ note likes (no
  post-likes term — no parent post). Cooldown rests each entry **individually** (there's no
  post to bench as a group), using the same `cooldown_hours` setting. "Unattached" means the
  note has no parent Post/Categorization in *our* system — the reference note itself can
  still carry its own Substack post preview-card attachment, which travels along as the
  entry's `post_url` (see `Backfiller`/`Reseeder`) and rides along on every repost.
- `Substack::Blizzard::QuotationNote` — builds a Note `body_json` from a `SubstackQuotation`
  in the **Note** ProseMirror schema (blockquote + bold/italic/link marks; Notes have no
  heading or paragraph alignment): a bold post-title link, the italic quote trailed by a 🔗
  to the original comment, the linked author, and a **"More at the Reviews Page (`<url>`)"**
  line — mirroring the post-footer syncQuotations template. A manually-posted quotation Note
  doesn't get an automatic preview-card attachment (that was the retired ticker's job) —
  add one by hand in Substack's composer if you want it. **Reviews-link gotcha:** the
  reviews-page URL is emitted as **plain text, unmarked** — an explicit `link` mark to
  that URL gets **stripped on publish** (it's a `type:"page"`, not a card-able post;
  stripped even with descriptive anchor text), whereas a **bare URL in plain text is
  auto-linkified and kept** by Substack. Don't re-wrap it in a link mark. (The
  post-title/comment/author links survive because they sit on non-URL anchor text.)
- `Substack::Blizzard::QuotationPreviewer` (⚠️ **currently non-functional** — it posts a
  real Note via `Substack::Client#create_note` to eyeball rendering, which is blocked
  the same as any other automated Note-creation; kept for reference / in case a
  workaround ever exists) — fetches the built note from prod
  (`GET /admin/substack-blizzard/quotation/preview.json`, random or `?id=`, nothing
  claimed), driven by the `substack:blizzard:preview_quotation` task (below).
- `Substack::Blizzard::RepostRecorder` — records a completed repost (append
  `{url, timestamp, likes: 0}` to the entry by `uid`, idempotent by url). A blank
  `categorization_id` targets `BlizzardScheduleConfig` instead of a categorization — the
  unattached pool. Used by the admin's Add-manually forms via `#add_note`.
- `Substack::Blizzard::QuotationRecorder` — the quotation-pool equivalent: appends
  `{url, timestamp, likes: 0}` directly to a `SubstackQuotation#notes`, idempotent by
  url. `#add_note` delegates to this instead when given a `quotation_id`.
- `Substack::Blizzard::RepostTicker` (⚠️ **retired, unused** — automated posting is
  gone) — used to run on a local Mac cron: ask prod for the next weighted repost,
  create the Note from a residential IP, confirm it back. The code is still here, and
  `POST /repost/tick.json` / `POST /repost/confirm.json` are still routed, but nothing
  invokes any of it anymore.
- `RefreshNotePostLikesJob` — daily SolidQueue job; walks every Substack categorization on
  the prod worker and refreshes both note likes and each post's likes. `BackfillAllJob` /
  `BackfillPostJob` — backfill jobs. See
  [refresh_note_post_likes_job.md](refresh_note_post_likes_job.md) and
  [solid_queue.md](solid_queue.md).

## Authentication / the cookie

Get `substack.sid` from a logged-in browser: DevTools → Application → Cookies →
`https://substack.com` → `substack.sid` (HttpOnly, so the Console can't read it). Only
needed on **prod** now — nothing posts through this app's stored cookie anymore, only
reads (backfill, likes, re-seed, and the Add-manually timestamp lookup below).

```bash
ssh noob@<prod> 'cd ~/blog/current && SID="s%3A…" RAILS_ENV=production \
  ~/.rbenv/bin/rbenv exec bundle exec rails runner \
  "SubstackSyncConfig.instance.update!(session_cookie: ENV[\"SID\"])"'
```

If the cookie expires you get a clear `AuthError` (an admin flash on backfill/re-seed;
the Add-manually timestamp lookup just silently falls back to `Time.current` instead —
see "Adding a repost" below). Re-run with a fresh value.

## The admin page

### Repost selection (settings)

A small form sets **Suggest a new repost every (minutes)** and **Per-post cooldown
(hours)** (POSTs to `#update_settings`), and shows when a suggestion was last claimed.
Selection itself is automatic (74% weighted per-post text group, 24% random quotation,
2% weighted unattached note) — there's no schedule to arrange, and nothing posts on
its own. The shares are the `QUOTATION_ODDS`/`UNATTACHED_ODDS` constants, not form
fields. The **"Most likely to be suggested next"** table below is a leaderboard of the
74% per-post pool's current odds; **"Next repost suggestion"** is a live draw (a fresh
weighted pick every page load) across all three pools, with the same rich-copy +
Add-manually tooling as the due list below.

### Unattached Notes

A JSON textarea editing `BlizzardScheduleConfig#data` directly (paste Note URLs into its
`"notes"` key, save), a **Backfill unattached Notes** button (`BackfillUnattachedNotesJob`),
and that's it — no *standing* due-list UI for this pool (small enough, and edited by
hand); an unattached entry can still turn up in the "Next repost suggestion" draw above,
complete with its own Add-manually form. Tracked entries accumulate under `"blizzard"`
in the same textarea once backfilled.

### Due list, re-seed, manual paste-back

`DueFinder` lists entries whose most-recent note is older than the **Days** filter (1–60),
most-stale-first, 20/page. Per entry: a **Copy** button (rich text — see `to_html`
above), an **Add manually** form (paste the Note URL you posted by hand; the timestamp
is resolved automatically from Substack, no manual entry needed — see below), and
**Re-seed rich text** (paste a real Note URL to replace that entry's `body_json`/`text`;
history untouched).

**Adding a repost**: paste the URL into Add-manually and submit — `#add_note` extracts
the comment id and reads the Note's real creation time via `Substack::Client#get_note`
(falling back to `Time.current` if the URL isn't recognizable, the cookie's stale, or
the lookup otherwise fails), then records it via `RepostRecorder` (or
`QuotationRecorder` for a quotation). No timestamp field to fill in by hand.

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
2. **Suggest** (on page load): the admin's "Next repost suggestion" panel calls
   `WeightedPicker.execute(dry_run: true)` in-process — a fresh weighted draw every
   reload, claiming nothing.
3. **Post** (a human, in their own browser): copy the suggested (or any due-list) rich
   text, paste it into a new Substack Note, post it.
4. **Record**: paste the resulting Note URL into that entry's Add-manually form.
   `#add_note` resolves the real timestamp from Substack and appends it to the entry's
   (or quotation's) tracked `notes`.

**Text vs. quotation vs. unattached (74 / 24 / 2):** on each due pick, `WeightedPicker`
rolls one random number against three cumulative bands: `[0, QUOTATION_ODDS)` (0.24) →
a random `SubstackQuotation` ([the Quotations pool](substack_post_sync.md#quotations))
built into a Note by `QuotationNote`; `[QUOTATION_ODDS, QUOTATION_ODDS + UNATTACHED_ODDS)`
(0.02) → the weighted unattached pick below; the remaining `[0.26, 1)` (0.74) → the
weighted per-post text pick below. An empty tier falls through to the next one
(quotation → unattached → text). Quotation reposts **are** tracked — recorded onto the
`SubstackQuotation`'s own `notes` via `QuotationRecorder`, shown on
`/admin/quotations`, not counted in the per-post-text odds leaderboard. Unattached
reposts **are** tracked too (`uid` set, `categorization_id` blank — `RepostRecorder`
targets `BlizzardScheduleConfig` instead of a categorization).

**Weighting (per-post 74% and unattached 2%):** an entry's pick probability ∝
`1 + Σ(its notes' likes)`, plus its post's likes for the per-post pool (no such term for
unattached — no parent post). The `+1` base gives never-posted / zero-like entries a small
chance; the sums make heavily-liked entries (and popular posts — a post's likes lift every
one of its entries — and, deliberately, entries reposted often) win more. Entries with no
`body_json` are excluded; so are entries in cooldown — as a whole **post** (all its
entries) for the per-post pool, or **individually** for the unattached pool (no post to
bench as a group) — both against the same `cooldown_hours` setting.

## Adding a new original Note

1. Compose the rich Note in Substack's editor (include the post's preview card), post it.
2. Add its URL to that post's `data["notes"]` (Post edit `#data` editor).
3. **Backfill this post** (button) — original text → a new blizzard entry (with a `uid`)
   with lossless `body_json`. It enters the weighted pool automatically.

## Rake tasks

| Task | Status | What |
|------|--------|------|
| `substack:blizzard:tick[_dry_run]` | ⚠️ retired, unused | Used to post the next weighted repost from a local Mac cron; the cron's gone and `tick` would 403 regardless (Note-creation is blocked). `tick_dry_run` still runs harmlessly but is redundant with the admin page's own in-process preview. |
| `substack:blizzard:preview_quotation` | ⚠️ non-functional | Posts a quotation Note to eyeball rendering — blocked, same as any automated Note-creation. |
| `substack:blizzard:proof` | ⚠️ non-functional | Round-trip test incl. posting a throwaway Note — the create step is blocked. |
| `substack:blizzard:backfill[_dry_run]` | live | Build `blizzard` from `notes` URLs (also via the buttons). |
| `substack:blizzard:append_urls[_dry_run]` | live | Append each entry's post URL to its `body_json` — covers per-post categorizations (shared canonical `#url`) *and* the unattached pool (each entry's own `post_url`). |
| `substack:blizzard:fill_missing_body_json[_dry_run]` | live | Plain `body_json` from text for entries lacking it (lossy) — pure local text transform, no Substack calls. |

`_dry_run` variants write nothing. All writing tasks are idempotent.

## body_json and the post URL

The stored `body_json` ends with the post URL as an **inline link paragraph**
(`append_urls`) — this is the only posting path now (manual copy-paste), so every
entry's copy source should carry it. (A retired automated path used to strip that
inline URL and re-add the post as a card attachment instead, matching Substack's own
UI when it created the Note directly — that distinction no longer applies.)

Rich formatting only survives if captured from a real Note (backfill / re-seed).
`fill_missing_body_json` is a last-resort fallback producing **plain** paragraphs.

## Troubleshooting

- **"Next repost suggestion" always says "Nothing due right now"** — check
  `interval_minutes` and `last_reposted_at`. Since nothing calls the non-dry-run
  picker anymore, `last_reposted_at` no longer advances on its own — if it's stuck far
  in the past, `due?` is (harmlessly) permanently true instead; if it looks frozen at
  a *future-seeming* or otherwise wrong value, that's worth a closer look.
- **A resolved timestamp doesn't match what you expected** — `#add_note` falls back to
  `Time.current` silently if the Substack lookup fails (stale cookie, unrecognized
  URL, network error); refresh the prod cookie if the pulled timestamps should be
  exact.
- **Likes all zero / stale** — the daily `RefreshNotePostLikesJob` hasn't run (SolidQueue
  worker down; see [solid_queue.md](solid_queue.md)); hit "Refresh all Note/Post likes" to
  force it.
- **Entry never suggested** — its post may be permanently in cooldown (any of the post's
  entries has a very recent note), or the entry lacks `body_json` (re-seed it, or
  `fill_missing_body_json`).
