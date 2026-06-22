# frozen_string_literal: true

require "net/http"
require "json"

# Runs LOCALLY (residential IP, to clear Cloudflare) but operates on a remote
# (prod) instance: fetches due text-groups from prod's JSON API, creates a fresh
# Substack Note for each via Substack::Client, and posts the resulting
# {url, timestamp} back to prod. Server-side note creation is blocked by
# Cloudflare from the datacenter IP, hence this Mac-driven path.
module Substack
  module Blizzard
    class RemoteReposter
      include ServiceInterface

      arguments :base_url, :username, :password,
                days: 30, limit: nil, commit: true, substack: nil

      PACING = 5 # seconds between posts, to stay gentle on Substack

      Result = Struct.new(:posted, :failed, :skipped, keyword_init: true)

      def execute
        @substack ||= Substack::Client.new
        posted  = []
        failed  = []
        skipped = []

        due_groups.each do |group|
          # Can't repost a group with no rich content — would publish an empty Note.
          if group["body_json"].blank?
            skipped << { "text" => group["text"], "reason" => "no body_json" }
            next
          end

          unless @commit
            posted << { "text" => group["text"], "dry_run" => true }
            next
          end

          begin
            posted << repost(group)
          rescue => e
            failed << { "text" => group["text"], "error" => e.message }
          end
          sleep PACING
        end

        Result.new(posted: posted, failed: failed, skipped: skipped)
      end

      private

      def due_groups
        groups = JSON.parse(get("/admin/substack-blizzard/due.json?days=#{@days.to_i}"))
        @limit ? groups.first(@limit.to_i) : groups
      end

      def repost(group)
        created = NoteParser.comment(@substack.create_note(group["body_json"]))
        record  = {
          "url"       => NoteParser.build_note_url(group["template_url"], created["id"]),
          "timestamp" => NoteParser.timestamp(created) || Time.current.utc.iso8601
        }
        post_back(group, record)
        record.merge("text" => group["text"])
      end

      def post_back(group, record)
        post("/admin/substack-blizzard/add-note.json",
             categorization_id: group["categorization_id"],
             index:             group["index"],
             url:               record["url"],
             timestamp:         record["timestamp"])
      end

      def get(path)
        request(Net::HTTP::Get.new(uri(path)))
      end

      def post(path, params)
        req = Net::HTTP::Post.new(uri(path))
        req.set_form_data(params)
        request(req)
      end

      def request(req)
        req.basic_auth(@username, @password)
        res = Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: req.uri.scheme == "https") do |http|
          http.request(req)
        end
        raise "prod API #{res.code}: #{res.body.to_s[0, 200]}" unless res.code.to_i.between?(200, 299)
        res.body
      end

      def uri(path)
        URI.join(@base_url, path)
      end
    end
  end
end
