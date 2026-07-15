# frozen_string_literal: true

require "net/http"
require "base64"

# Mirrors a Comfy blog post into a Substack draft (never publishes — publishing
# is the only email-triggering step and stays a separate, deliberate action).
# Idempotent: the first sync creates a draft and stores its id on the post;
# later syncs PUT that same draft. Draft writes are not Cloudflare-blocked from
# the server IP, so this runs on the prod worker.
module Substack
  class PostSyncer
    include ServiceInterface

    arguments :post_id, client: nil, config: nil

    def execute
      # Draw the blog routes if a bare context (e.g. a job before a web request)
      # left them unloaded, so ComfyBlog.config.public_blog_path — and thus
      # post.url's "/blog" prefix — is populated. No-op once routes are loaded.
      Rails.application.routes_reloader.execute_unless_loaded

      post = Comfy::Blog::Post.find(@post_id)
      @config ||= SubstackSyncConfig.instance
      @client ||= Substack::Client.new(publication_host: @config.publication_host)

      doc = HtmlToProseMirror.execute(html: post.content_cache.to_s, image_resolver: method(:resolve_image))
      # Drop any Original link the post baked into its own body (often a stale
      # slug); the mirror owns that block, canonically rebuilt from post.url.
      doc["content"].reject! { |block| original_link_block?(block) }
      # Everything below the body is the stored template (Original link, footer
      # boilerplate, random quotations, tag-conditional sections), resolved per
      # post — directives expand here and never reach Substack.
      doc["content"].concat(TemplateResolver.resolve(@config.footer_json, post: post))
      subtitle = @config.subtitle_for(post)
      bylines  = [{ id: @config.author_id, is_guest: false }]

      categorization = substack_categorization(post)
      substack_id    = resolve_substack_id(categorization)

      if substack_id
        # Existing Substack post — edit it in place, keyed off the stable id.
        remote = @client.get_draft(substack_id)
        @client.update_draft(substack_id,
          draft_title: post.title.to_s, draft_subtitle: subtitle,
          draft_body: JSON.generate(doc), draft_bylines: bylines,
          audience: post.substack_audience, should_send_email: false)
        if remote["is_published"]
          # Push edits to an already-published post live immediately (the email
          # was sent at first publish, so this never re-sends). Never re-slug a
          # published post — that would change its public URL.
          @client.publish_draft(substack_id)
        else
          # Still a draft — safe to (re-)slug it to match the Comfy post.
          apply_slug(substack_id, post, bylines)
        end
        reconcile_url!(categorization, remote)
        substack_id
      else
        # No linked Substack post yet — create a fresh draft and record it as a
        # Substack categorization (id in #data; URL self-heals to /p/slug once
        # published). First publish stays a deliberate, manual step.
        created = @client.create_draft(title: post.title.to_s, subtitle: subtitle, body_doc: doc,
          bylines: bylines, audience: post.substack_audience)
        # Give the new post the Comfy post's slug (new drafts only — never
        # re-slug an existing published post). Substack ignores slug on create,
        # so it's a follow-up update.
        apply_slug(created.fetch("id"), post, bylines)
        apply_default_tags(created.fetch("id"))
        link_categorization!(post, categorization, created)
        created.fetch("id")
      end
    end

    private

    def substack_categorization(post)
      post.categorizations.joins(:category).find_by(comfy_cms_categories: { label: "Substack" })
    end

    # The Substack post id for a categorization: the stored data["id"] if present,
    # else resolved from a legacy /p/ published URL (and backfilled onto the
    # categorization so later syncs skip the lookup). nil when nothing links yet.
    def resolve_substack_id(categorization)
      return nil unless categorization

      id = categorization.data["id"]
      return id if id.present?

      url = categorization.url.to_s
      return nil unless url.include?("/p/")

      remote_id = @client.get_post(url).fetch("id")
      categorization.update!(data: categorization.data.merge("id" => remote_id))
      remote_id
    end

    # Point the categorization at the post's current canonical URL: the public
    # /p/slug once published, otherwise the draft editor URL.
    def reconcile_url!(categorization, remote)
      url = canonical_url(remote)
      categorization.update!(url: url) if categorization.url != url
    end

    # Record a freshly-created draft as a Substack categorization — populating an
    # existing one that lacks an id, or creating one — never duplicating.
    def link_categorization!(post, categorization, created)
      url = canonical_url(created)
      if categorization
        categorization.update!(url: url, data: categorization.data.merge("id" => created.fetch("id")))
      else
        Comfy::Cms::Categorization.create!(
          category:    substack_category(post.site),
          categorized: post, url: url, data: { "id" => created.fetch("id") }
        )
      end
    end

    # Set a new draft's slug to the Comfy post's slug, normalised to Substack's
    # rules (lowercase, [a-z0-9-], 2–255 chars). Best-effort: a slug that's too
    # short or rejected (e.g. already taken) is skipped, never failing the sync.
    def apply_slug(draft_id, post, bylines)
      slug = post.slug.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
      return unless slug.length.between?(2, 255)

      @client.update_draft(draft_id, slug: slug, draft_bylines: bylines)
    rescue Substack::Client::Error => e
      Rails.logger.warn("[SubstackSync] could not set slug #{slug.inspect} on #{draft_id}: #{e.message}")
    end

    # Assign the publication's default tags to a new post. Best-effort per tag so
    # one failure never breaks the sync. New posts only — applied on create.
    def apply_default_tags(post_id)
      Array(@config.default_tags).each do |tag|
        @client.add_tag(post_id, tag["id"])
      rescue Substack::Client::Error => e
        Rails.logger.warn("[SubstackSync] could not add tag #{tag["name"].inspect}: #{e.message}")
      end
    end

    def substack_category(site)
      Comfy::Cms::Category.find_or_create_by!(site: site, label: "Substack", categorized_type: "Comfy::Blog::Post")
    end

    def canonical_url(remote)
      host = @config.publication_host
      if remote["is_published"] && remote["slug"].present?
        "https://#{host}/p/#{remote["slug"]}"
      else
        "https://#{host}/publish/post/#{remote.fetch("id")}"
      end
    end

    # A block is a stray Original link if it's a paragraph/heading whose text
    # starts with "Original:" and carries a link mark.
    def original_link_block?(block)
      return false unless %w[paragraph heading].include?(block["type"])

      texts = []
      linked = false
      walk = lambda do |node|
        return unless node.is_a?(Hash)

        if node["type"] == "text"
          texts << node["text"].to_s
          linked ||= Array(node["marks"]).any? { |m| m["type"] == "link" }
        end
        Array(node["content"]).each { |child| walk.call(child) }
      end
      walk.call(block)

      linked && texts.join.strip.match?(/\AOriginal:/i)
    end

    def resolve_image(src)
      data = download_image(src)
      return nil unless data

      body = ImageUpscaler.fill(data[:body], data[:content_type])
      @client.upload_image("data:#{data[:content_type]};base64,#{Base64.strict_encode64(body)}")
    rescue => e
      Rails.logger.warn("[SubstackSync] image upload failed for #{src}: #{e.message}")
      nil
    end

    # Reads local ActiveStorage blobs straight from storage (avoiding an HTTP
    # round-trip back into the same process); falls back to a plain GET otherwise.
    def download_image(url)
      if (match = url.match(%r{/rails/active_storage/blobs/(?:redirect|inline)/([^/]+)/}))
        blob = ActiveStorage::Blob.find_signed!(match[1])
        return { body: blob.download, content_type: blob.content_type || "image/jpeg" }
      end

      uri = URI(url)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                            open_timeout: 10, read_timeout: 30) { |http| http.get(uri.request_uri) }
      return nil unless res.is_a?(Net::HTTPSuccess)

      { body: res.body, content_type: res["content-type"]&.split(";")&.first&.strip || "image/jpeg" }
    rescue => e
      Rails.logger.warn("[SubstackSync] image download failed for #{url}: #{e.message}")
      nil
    end
  end
end
