# frozen_string_literal: true

# Resolves the Substack account that owns a target URL (a post, or a comment/note
# being replied to): { "name", "handle", "user_id" }. A comment/note URL resolves
# to the commenter; a post URL resolves to its first byline author.
module Substack
  class TargetResolver
    include ServiceInterface

    arguments :url, client: nil

    def execute
      @client ||= Substack::Client.new
      comment_id = comment_id_from(@url)
      comment_id ? from_comment(comment_id) : from_post
    end

    private

    def comment_id_from(url)
      Substack::NoteParser.comment_id_from_url(url) || url.to_s[%r{/comment/(\d+)}, 1]
    end

    def from_comment(comment_id)
      comment = Substack::NoteParser.comment(@client.get_note(comment_id))
      author(comment["name"], comment["handle"], comment["user_id"])
    end

    def from_post
      byline = Array(@client.get_post(@url)["publishedBylines"]).first || {}
      author(byline["name"], byline["handle"], byline["id"])
    end

    def author(name, handle, user_id)
      { "name" => name, "handle" => handle, "user_id" => user_id }
    end
  end
end
