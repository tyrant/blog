# Substack CSS classes

The custom CSS classes a post's body HTML can carry to steer how it syncs to
Substack. All of them are recognised in one place —
`Substack::HtmlToProseMirror` (`app/services/substack/html_to_prose_mirror.rb`),
which converts a post's `content_cache` HTML into the ProseMirror `doc` that
Substack's `draft_body` expects. There is no other consumer: a class Substack
doesn't know about is silently ignored (its text still survives).

Author these by hand in the editor's HTML view — the class must sit on the exact
element noted below. Related flow doc: [substack_post_sync.md](substack_post_sync.md).

## Summary

| Class            | Goes on   | Substack effect                                    | Comfy-site effect            |
|------------------|-----------|----------------------------------------------------|------------------------------|
| `img-large`      | `<img>`   | `imageSize: "large"`, `resizeWidth: 1200`          | like normal (no CSS yet)     |
| `img-full`       | `<img>`   | `imageSize: "full"`, `resizeWidth: nil`            | **full-bleed** below `lg`    |
| `caption`        | `<p>`     | folds the paragraph into the preceding image's `caption` | plain paragraph        |
| `callout-block`  | `<p>`     | becomes a Substack `calloutBlock`                  | plain paragraph              |

Nothing else is special-cased. An `<img>` with no size class, or a class
Substack doesn't recognise (e.g. `img-wide`), falls back to `imageSize:
"normal"` (`resizeWidth: 728`).

## Image width — `img-large`, `img-full`

Set with `IMAGE_SIZE_CLASSES = { "img-large" => "large", "img-full" => "full" }`.
A plain `<img>` already syncs as a Substack `captionedImage` (re-hosted to
Substack's CDN); the class only picks its `imageSize`. Substack has three sizes,
and these are the only two beyond the `normal` default:

```html
<img class="img-full" src="…">
```

```json
{
  "type": "captionedImage",
  "content": [{
    "type": "image2",
    "attrs": { "src": "…", "imageSize": "full", "resizeWidth": null, "…": "…" }
  }]
}
```

- `resizeWidth` comes from `RESIZE_WIDTHS = { "normal" => 728, "large" => 1200 }`
  — it forces the image to fill Substack's content column rather than defaulting
  to its native width. `full` gets `nil` (Substack sizes it itself).
- One size class per image; put it on the `<img>` itself, not a wrapper.
- The class won't survive re-uploading/replacing the image in the editor, so add
  it once the image is settled.
- On the Comfy site, `img-full` breaks the image out to full-bleed below the `lg`
  breakpoint (CSS in `application.tailwind.css`); `img-large` currently has no
  site-side CSS and renders like normal.

## Image caption — `caption`

Opt-in. A `<p class="caption">` **directly after an image** folds into that image
as Substack's `caption` node (`fold_captions`). An unmarked paragraph after an
image stays body text.

```html
<img src="…">
<p class="caption">Photo: someone</p>
```

```json
{
  "type": "captionedImage",
  "content": [
    { "type": "image2", "attrs": { "…": "…" } },
    { "type": "caption", "content": [ { "type": "text", "text": "Photo: someone" } ] }
  ]
}
```

Only folds when the paragraph immediately follows a `captionedImage` that has no
caption yet; otherwise it stays an ordinary paragraph. The internal `_caption`
marker is transient and never reaches Substack.

## Callout — `callout-block`

A `<p class="callout-block">` becomes Substack's `calloutBlock`. Substack has no
soft-break node, so a run of `<br><br>` inside the paragraph splits into separate
callout paragraphs (same handling as blockquotes); each carries
`attrs.textAlign` to match Substack's shape.

```html
<p class="callout-block">First line.<br><br>Second line.</p>
```

```json
{
  "type": "calloutBlock",
  "content": [
    { "type": "paragraph", "attrs": { "textAlign": null }, "content": [ { "type": "text", "text": "First line." } ] },
    { "type": "paragraph", "attrs": { "textAlign": null }, "content": [ { "type": "text", "text": "Second line." } ] }
  ]
}
```

An empty callout (no inline content) is dropped. On the Comfy site it renders as
a plain paragraph.
