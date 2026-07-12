# frozen_string_literal: true

# Given the URL of a reply the user posted (a comment on a post, a reply to a
# comment, or a Note reply), fetch its context from Substack and derive what it
# replied to: the target's URL + owner, and the reply's timestamp. Lets the
# Reply Tracker take just the reply URL and fill the rest itself.
module Substack
  class ReplyResolver
    include ServiceInterface

    arguments :reply_url, client: nil

    Result = Struct.new(:target_url, :author_name, :author_handle, :author_user_id, :replied_at,
                        :target_preview, :reply_preview, :ancestor_path, keyword_init: true)

    def execute
      @client ||= Substack::Client.new
      comment_id = Substack::NoteParser.comment_id_from_url(@reply_url) || @reply_url.to_s[%r{/comment/(\d+)}, 1]
      raise ArgumentError, "Not a Substack comment or note URL: #{@reply_url}" if comment_id.blank?

      item          = @client.get_note(comment_id)["item"] || {}
      reply         = item["comment"] || {}
      replied_at    = reply["date"]
      reply_preview = plaintext(reply)
      ancestor_path = reply["ancestor_path"]

      if ancestor_path.to_s.present?
        parent = Array(item["parentComments"]).last || {}
        result(parent_url(parent, item["post"]), parent["name"], parent["handle"], parent["user_id"],
               replied_at, plaintext(parent), reply_preview, ancestor_path)
      else
        post   = item["post"] || {}
        byline = Array(post["publishedBylines"]).first || {}
        result(post["canonical_url"], byline["name"], byline["handle"], byline["id"],
               replied_at, post["title"], reply_preview, ancestor_path)
      end
    end

    private

    def plaintext(comment)
      bj = comment["body_json"]
      bj.present? ? Substack::NoteParser.plaintext(bj).to_s : ""
    end

    # The parent's URL, in the same form as the reply's own URL: a Note thread
    # (reply URL under /note/) links to the parent's note; a post-comment thread
    # links to the parent comment on its post. (post_id is set for both — a note
    # thread can be rooted at a note sharing a post — so it can't be the signal.)
    def parent_url(parent, post)
      if @reply_url.to_s.include?("/note/")
        "https://substack.com/profile/#{parent["user_id"]}-#{parent["handle"]}/note/c-#{parent["id"]}"
      else
        "#{(post || {})["canonical_url"]}/comment/#{parent["id"]}"
      end
    end

    def result(target_url, name, handle, user_id, replied_at, target_preview, reply_preview, ancestor_path)
      Result.new(target_url: target_url, author_name: name, author_handle: handle,
                 author_user_id: user_id, replied_at: replied_at,
                 target_preview: target_preview, reply_preview: reply_preview, ancestor_path: ancestor_path)
    end
  end
end
