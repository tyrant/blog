# frozen_string_literal: true

# Given the URL of a Substack comment, fetch its context and derive the post it
# was made on (url + title) and the commenter (name + profile url). Lets the
# Quotations admin take just the comment URL and the blurb, filling the rest.
# A quotation with no comment or note to point at (e.g. a blurb on someone's
# /recommendations page) may instead use any substack.com page URL: there's
# nothing to look up, so it stands in for the publication itself, like
# PostMetadata's GENERIC_POST_URL, with no author.
module Substack
  class QuotationResolver
    include ServiceInterface

    arguments :comment_url, client: nil

    Result = Struct.new(:post_url, :post_title, :post_image_url, :post_id, :author_name, :author_handle,
                        :author_user_id, keyword_init: true)

    def execute
      @client ||= Substack::Client.new
      comment_id = Substack::NoteParser.comment_id_from_url(@comment_url) || @comment_url.to_s[%r{/comment/(\d+)}, 1]
      if comment_id.blank?
        return generic_result if substack_page?

        raise ArgumentError, "Not a Substack comment, note or page URL: #{@comment_url}"
      end

      item    = @client.get_note(comment_id)["item"] || {}
      comment = item["comment"] || {}
      post    = item["post"] || {}

      Result.new(
        post_url:       post["canonical_url"],
        post_title:     post["title"],
        post_image_url: post["cover_image"],
        post_id:        post["id"],
        author_name:    comment["name"],
        author_handle:  comment["handle"],
        author_user_id: comment["user_id"]
      )
    end

    private

    def generic_result
      Result.new(post_url:       PostMetadata::GENERIC_POST_URL,
                 post_title:     PostMetadata::GENERIC_POST_TITLE,
                 post_image_url: PostMetadata::FALLBACK_IMAGE_URL)
    end

    def substack_page?
      uri = URI.parse(@comment_url.to_s.strip)
      uri.is_a?(URI::HTTPS) && uri.host.to_s.match?(/\A([a-z0-9-]+\.)?substack\.com\z/i)
    rescue URI::InvalidURIError
      false
    end
  end
end
