# frozen_string_literal: true

require "net/http"

# Mirrors a Comfy blog post to Bluesky as a teaser (lead + title + canonical
# link) — Bluesky's 300-grapheme cap can't hold the full post, so this is always
# a link back to the blog, with a rich link card.
#
# Post-once: an existing "Bluesky" categorization means the post already shipped,
# so re-syncs no-op. Bluesky records are immutable — an "edit" would mean delete
# + re-create, minting a new URI and discarding likes/reposts — so re-posting is
# deliberately not automatic.
module Bluesky
  class PostSyncer
    include ServiceInterface

    MAX_BLOB_BYTES = 1_000_000

    arguments :post_id, client: nil, config: nil

    def execute
      # Draw the blog routes if a bare job context left them unloaded, so
      # post.url's "/blog" prefix is populated. No-op once routes are loaded.
      Rails.application.routes_reloader.execute_unless_loaded

      post = Comfy::Blog::Post.find(@post_id)
      @config ||= BlueskySyncConfig.instance
      @client ||= Bluesky::Client.new

      categorization = bluesky_categorization(post)
      existing = categorization&.data&.dig("uri")
      return existing if existing.present?

      url = canonical_url(post)
      teaser = TeaserBuilder.execute(post: post, url: url, lead: @config.lead_for(post))
      record = {
        "$type"     => "app.bsky.feed.post",
        "text"      => teaser[:text],
        "createdAt" => Time.now.utc.iso8601(3),
        "langs"     => ["en"],
        "facets"    => teaser[:facets],
        "embed"     => external_embed(post, url)
      }

      created = @client.create_post(record)
      link_categorization!(post, categorization, created)
      created.fetch("uri")
    end

    private

    def bluesky_categorization(post)
      post.categorizations.joins(:category).find_by(comfy_cms_categories: { label: "Bluesky" })
    end

    # A link card (uri + title + description + optional thumbnail). Bluesky never
    # fetches the target's OG tags itself, so the card — including the preview
    # image — is built and uploaded here from the post.
    def external_embed(post, url)
      external = {
        "uri"         => url,
        "title"       => post.title.to_s,
        "description" => description_for(post)
      }
      if (thumb = upload_thumb(post))
        external["thumb"] = thumb
      end
      { "$type" => "app.bsky.embed.external", "external" => external }
    end

    # Uploads the post's central image as the card thumbnail, resolving it from a
    # local ActiveStorage blob or a remote URL. Best-effort: any failure (no
    # image, oversized, download error) posts a card without a thumb rather than
    # failing the whole sync.
    def upload_thumb(post)
      image = thumbnail_image(post)
      return nil unless image && image[:bytes].bytesize <= MAX_BLOB_BYTES

      @client.upload_blob(image[:bytes], image[:content_type])
    rescue => e
      Rails.logger.warn("[BlueskySync] thumb upload failed for post #{post.id}: #{e.message}")
      nil
    end

    def thumbnail_image(post)
      src = post.first_img_src
      return nil if src.blank?

      if Comfy::Blog::Post.active_storage_url?(src)
        variant = Comfy::Blog::Post.resized_blob_variant_from(src, x: 1200, y: 630)
        return nil if variant.blank?

        # resize_to_fill preserves the source format, so the original blob's
        # content type matches the processed variant's bytes.
        { bytes: variant.processed.download, content_type: variant.blob.content_type }
      else
        fetch_remote_image(src)
      end
    end

    def fetch_remote_image(url)
      uri = URI(url)
      return nil unless uri.is_a?(URI::HTTP)

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                            open_timeout: 10, read_timeout: 30) { |http| http.get(uri.request_uri) }
      return nil unless res.is_a?(Net::HTTPSuccess)

      content_type = res["content-type"]&.split(";")&.first&.strip
      return nil unless content_type&.start_with?("image/")

      { bytes: res.body, content_type: content_type }
    end

    # Comfy's Site#url is protocol-relative ("//host/path"); Bluesky's URI
    # validator rejects that, so add the https scheme when it's missing.
    def canonical_url(post)
      url = post.url
      url.start_with?("//") ? "https:#{url}" : url
    end

    def description_for(post)
      text = Nokogiri::HTML(post.content_cache.to_s).text.squish
      text.length > 300 ? "#{text[0, 299]}…" : text
    end

    # Record the created post as a "Bluesky" categorization — populating an
    # existing empty one or creating a new one, never duplicating. Stores the
    # at:// uri + cid for dedupe, and the public bsky.app permalink as the URL.
    def link_categorization!(post, categorization, created)
      data = { "uri" => created.fetch("uri"), "cid" => created.fetch("cid") }
      if categorization
        categorization.update!(url: public_url(created), data: categorization.data.merge(data))
      else
        Comfy::Cms::Categorization.create!(
          category:    bluesky_category(post.site),
          categorized: post, url: public_url(created), data: data
        )
      end
    end

    # bsky.app permalink built from the record's rkey (the last at:// path segment).
    def public_url(created)
      rkey = created.fetch("uri").split("/").last
      "https://bsky.app/profile/#{@config.handle}/post/#{rkey}"
    end

    def bluesky_category(site)
      Comfy::Cms::Category.find_or_create_by!(site: site, label: "Bluesky", categorized_type: "Comfy::Blog::Post")
    end
  end
end
