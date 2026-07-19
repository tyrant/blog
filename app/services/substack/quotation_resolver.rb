# frozen_string_literal: true

# Given the URL of a Substack comment, fetch its context and derive the post it
# was made on (url + title) and the commenter (name + profile url). Lets the
# Quotations admin take just the comment URL and the blurb, filling the rest.
module Substack
  class QuotationResolver
    include ServiceInterface

    arguments :comment_url, client: nil

    Result = Struct.new(:post_url, :post_title, :post_image_url, :post_id, :author_name, :author_url, keyword_init: true)

    def execute
      @client ||= Substack::Client.new
      comment_id = Substack::NoteParser.comment_id_from_url(@comment_url) || @comment_url.to_s[%r{/comment/(\d+)}, 1]
      raise ArgumentError, "Not a Substack comment or note URL: #{@comment_url}" if comment_id.blank?

      item    = @client.get_note(comment_id)["item"] || {}
      comment = item["comment"] || {}
      post    = item["post"] || {}

      Result.new(
        post_url:       post["canonical_url"],
        post_title:     post["title"],
        post_image_url: post["cover_image"],
        post_id:        post["id"],
        author_name:    comment["name"],
        author_url:     profile_url(comment["handle"])
      )
    end

    private

    def profile_url(handle)
      "https://substack.com/@#{handle}" if handle.present?
    end
  end
end
