# frozen_string_literal: true

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

      teaser = TeaserBuilder.execute(post: post, url: post.url, lead: @config.lead_for(post))
      record = {
        "$type"     => "app.bsky.feed.post",
        "text"      => teaser[:text],
        "createdAt" => Time.now.utc.iso8601(3),
        "langs"     => ["en"],
        "facets"    => teaser[:facets],
        "embed"     => external_embed(post)
      }

      created = @client.create_post(record)
      link_categorization!(post, categorization, created)
      created.fetch("uri")
    end

    private

    def bluesky_categorization(post)
      post.categorizations.joins(:category).find_by(comfy_cms_categories: { label: "Bluesky" })
    end

    # A text-only link card (uri + title + description). Bluesky never fetches the
    # target's OG tags itself, so the card is built here from the post.
    def external_embed(post)
      {
        "$type" => "app.bsky.embed.external",
        "external" => {
          "uri"         => post.url,
          "title"       => post.title.to_s,
          "description" => description_for(post)
        }
      }
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
