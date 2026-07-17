# Substack Post Sync

Mirrors a Comfy blog post to a Substack post/draft. Triggered by the **"Sync to
Substack"** button on the post editor → `SubstackPostSyncJob` → `Substack::PostSyncer`,
running on the prod SolidQueue worker (draft writes aren't Cloudflare-blocked from the
datacenter IP — see [solid_queue.md](solid_queue.md)). No bulk autosync: posts are synced
one at a time on purpose.

Related: [substack_blizzard.md](substack_blizzard.md) (Notes), the Reply Tracker / Reply
Drafter, and the Tags feature all share `Substack::Client` (the unofficial-API wrapper).

## What a synced post looks like

```
[Title]                     ← post.title
[Subtitle]                  ← conditional, see "Subtitles"
[Body]                      ← content_cache HTML → ProseMirror (see "Authoring")
[Below-body template]       ← the stored, directive-driven template (see "Template")
```

- **Linkage:** the post's "Substack" `Comfy::Cms::Categorization` is the source of truth —
  `data["id"]` is the stable Substack post id; `url` is the canonical `/p/slug` (or the
  draft editor URL until published).
- **Audience:** the post's `substack_audience` column (`everyone` / `only_paid` /
  `founding`) maps to the draft's `audience`, set on the post form's "Substack audience"
  select.
- Published posts are edited in place and **re-published immediately** (no email is
  re-sent — that only happens at first publish, which stays a manual step).

## Authoring conventions (how Comfy content maps to Substack)

`Substack::HtmlToProseMirror` converts the post's `content_cache` HTML. Structure your
content this way so the sync reproduces what you want:

### Images

A plain `<img>` becomes a Substack `captionedImage` (re-hosted to Substack's CDN). Images
nested inside a heading (`<h2><img></h2>`) are pulled out automatically.

**Width** — add one class to the `<img>` (via the editor's HTML view). No class = normal.
One size class per image.

Substack has only three image sizes; these are the only classes it honours (`img-wide`
doesn't exist as a Substack size — an unknown class just falls back to `normal`):

| Class on `<img>`  | Substack `imageSize` | On the Comfy site               |
|-------------------|----------------------|---------------------------------|
| *(none)*          | `normal` (728px)     | unchanged                       |
| `img-large`       | `large` (1200px)     | like normal (no CSS yet)        |
| `img-full`        | `full`               | **full-bleed** below `lg`       |

> The class must be on the `<img>` itself, e.g. `<img class="img-full" src="…">`. It won't
> survive re-uploading/replacing the image in the editor, so add it once the image is settled.

**Caption** — opt-in: a paragraph marked `<p class="caption">` directly after an image becomes
that image's caption (`fold_captions`). Unmarked paragraphs after an image stay body text.
(`rake substack:harvest_captions` back-filled the class onto pre-existing implicit captions;
`EXCLUDE=id,id` skips posts whose caption you want dropped, `COMMIT=1` to write.)

### Videos

A YouTube video becomes Substack's `youtube2` player, from either form:

- an `<iframe src="…youtube.com/embed/ID…">` (also renders as a player on the Comfy site), or
- a paragraph that is **nothing but a YouTube URL/link** (`youtube.com/watch?v=ID`,
  `youtu.be/ID`) — mirrors Substack's paste-a-link behaviour.

`startTime` is read from a `t=`/`start=` param. A YouTube link *inline with other text*
stays a link, not a player.

## The below-body template

`SubstackSyncConfig#footer_json` is the **whole below-body template** (a ProseMirror-blocks
array), resolved per post by `Substack::TemplateResolver`. Literal blocks pass through;
three directive nodes expand at sync time and never reach Substack:

| Directive | Expands to |
|-----------|------------|
| `{"type":"syncOriginalLink"}` | the `Original: <post url>` heading |
| `{"type":"syncQuotations","attrs":{"count":N}}` | N random quotation triplets (see "Quotations") |
| `{"type":"syncIf","attrs":{"tag":"…"},"content":[…]}` | its blocks, only if the post has that tag |

### Subtitles

Two subtitle fields on `/admin/substack-sync`. `SubstackSyncConfig#subtitle_for(post)`
returns `subtitle` for `Shite Advice`-tagged posts, else `subtitle_default`.

### Editing the template (canonical-draft workflow)

Don't hand-edit the JSON. Instead:

1. Edit a **canonical Substack draft** (currently **206980888**) like any post.
2. Hit **"Re-capture template from a reference draft"** on `/admin/substack-sync` (or run
   `rake substack:capture_footer`).

`Substack::TemplateCapturer` takes everything from the first `Original:` heading down as the
template, turning the dynamic bits back into directives: the Original heading →
`syncOriginalLink`, the run of quotation triplets → `syncQuotations`, and each configured
conditional section → `syncIf`. Conditionals are declared in `TemplateCapturer::CONDITIONALS`
(currently: a heading containing `Bullshit Emeritus` → gated on the `Shite Advice` tag).

## Quotations

Reader-comment blurbs collected at `/admin/quotations` (a `SubstackQuotation` per blurb:
paste a comment URL + the quote, and the post/commenter are looked up). The
`syncQuotations` directive renders `count` random ones, each a triplet: an h4 heading linking
the post, an italic blockquote of the quote, and a right-aligned line linking the commenter.
Sampling (`SubstackQuotation.sample_excluding`) is distinct by quote text — so the same quote
never appears twice — and excludes quotations left on the post being rendered.

- **Weekly rotation** — `RotateSubstackQuotationsJob` (`config/recurring.yml`, every 7 days
  at 6am) swaps each post's quotation triplets for fresh random ones and re-publishes live
  posts. **Gated by the "Rotate featured quotes weekly" switch** on `/admin/substack-sync`
  (`quotation_rotation_enabled`, default **off**). The schedule always fires but no-ops
  unless the switch is on.

## Divergence scanner

`rake substack:scan_divergences` (read-only) rebuilds each synced post's Comfy body (without
uploading images) and diffs it against the live Substack draft, flagging manual Substack-only
tweaks a resync would clobber:

| Flag | Meaning |
|------|---------|
| `WIDTH` | image `imageSize` differs between Comfy and Substack |
| `CAPTION` | a caption on Substack that Comfy wouldn't produce |
| `VIDEO+n` | `youtube2`/embeds on Substack that Comfy lacks |
| `IMG±n` | image-count difference |
| `BLOCKS+n` | Substack body has extra blocks (roughest signal) |

As you fold a divergence into Comfy (e.g. add an `img-full` class), its flag clears — so the
scan doubles as a checklist before batch-resyncing.

## Key files

- `app/services/substack/post_syncer.rb` — orchestration
- `app/services/substack/html_to_prose_mirror.rb` — content HTML → ProseMirror (images,
  widths, captions, videos)
- `app/services/substack/template_resolver.rb` / `template_capturer.rb` — the template engine
- `app/services/substack/quotation_block.rb`, `app/jobs/rotate_substack_quotations_job.rb`
- `app/services/substack/divergence_scanner.rb`
- `app/models/substack_sync_config.rb`, `app/models/substack_quotation.rb`
- `app/services/substack/client.rb` — the unofficial-API wrapper
