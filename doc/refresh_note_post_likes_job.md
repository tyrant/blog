# RefreshNotePostLikesJob

Refreshes the Substack "likes" that drive the [Substack Blizzard](substack_blizzard.md)
popularity-weighted reposter: every note's like count **and** every post's like count.

## What it does

For every Substack `Comfy::Cms::Categorization` (post tagged "Substack"), via
`Substack::Blizzard::LikesRefresher`:

- **Note likes** — for each note in `data["blizzard"][*]["notes"]`, fetches the note
  (`Substack::Client#get_note`) and writes its `reaction_count` (the ❤ count) to the note's
  `"likes"` key.
- **Post likes** — fetches the categorization's Substack post
  (`Substack::Client#get_post`, from `categorization.url`) and writes its `reaction_count`
  to the post's `comfy_blog_posts.substack_likes` column.

These feed `Substack::Blizzard::RepostOdds`, where an entry's repost weight is
`1 + Σ(note likes) + post likes` — so a popular post lifts every one of its entries.

## Where / when it runs

- **Prod worker only.** Substack *reads* are allowed from the datacenter IP (only note
  *creation* is Cloudflare-blocked), so the job runs on the prod SolidQueue worker. See
  [solid_queue.md](solid_queue.md).
- **Daily at 4am** (NZ), via `config/recurring.yml` (recurring key `refresh_note_post_likes`).
- **On demand** from the admin: the **"Refresh all Note/Post likes"** button on
  `/admin/substack-blizzard` → `SubstackBlizzardController#refresh_likes` →
  `RefreshNotePostLikesJob.perform_later`.

## Behaviour

- **Sequential, paced** — one categorization at a time with a 1s gap (`PACING`), plus the
  client's own 429 backoff, to stay under Substack's rate limit. ~1,300 note reads + ~190
  post reads ≈ 20–25 min.
- **Idempotent** — it overwrites the counts; safe to re-run any time.
- **Tolerant** — a note or post that fails to fetch (deleted, transient error) keeps its
  last-known value rather than being zeroed; the error is logged and the run continues.
  A whole categorization that raises is logged and skipped (`RefreshNotePostLikesJob` rescues
  per-record).

## Related

- `app/jobs/refresh_note_post_likes_job.rb` — the job (iterates + paces).
- `app/services/substack/blizzard/likes_refresher.rb` — per-categorization work.
- `app/services/substack/client.rb` — `get_note` / `get_post`.
- [substack_blizzard.md](substack_blizzard.md) — the feature this feeds.
