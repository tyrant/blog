# frozen_string_literal: true

# A Substack post's own title and hero image, so the Quotations admin can derive
# both from the post URL rather than have them typed in and drift.
module Substack
  class PostMetadata
    include ServiceInterface

    arguments :post_url, client: nil

    # Stand-in thumbnail for a post with no hero image — the winky-kissy-face emoji.
    FALLBACK_IMAGE_URL = "https://substackcdn.com/image/fetch/$s_!K0Xj!,w_80,h_80,c_fill,f_webp,q_auto:good," \
                         "fl_progressive:steep/https%3A%2F%2Fsubstack-post-media.s3.amazonaws.com%2Fpublic" \
                         "%2Fimages%2Fe191c435-57f6-442d-9912-720cbae43dcb_700x700.png"

    # Some quotations aren't about a specific post (e.g. a comment on a note) and
    # use the publication's own base URL as a stand-in post_url — not a resolvable
    # /p/<slug> post, so skip the lookup rather than erroring.
    GENERIC_POST_URL = "https://mikeyclarke.substack.com"

    Result = Struct.new(:post_title, :post_image_url, :post_id, keyword_init: true)

    def execute
      return Result.new(post_title: nil, post_image_url: nil, post_id: nil) if generic?

      @client ||= Substack::Client.new
      post = @client.get_post(@post_url)

      Result.new(
        post_title:     post["title"],
        post_image_url: post["cover_image"].presence || FALLBACK_IMAGE_URL,
        post_id:        post["id"]
      )
    end

    private

    def generic?
      @post_url.to_s.chomp("/") == GENERIC_POST_URL
    end
  end
end
