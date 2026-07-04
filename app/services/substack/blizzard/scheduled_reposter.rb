# frozen_string_literal: true

require "net/http"
require "json"

# Runs LOCALLY (residential IP, to clear Cloudflare) driving a remote (prod)
# instance: claims due scheduled reposts from prod, creates a fresh Substack Note
# for each via Substack::Client, and confirms each back to prod. Two-phase — claim
# then confirm — so a crashed run's claims are reclaimed later rather than lost.
# Server-side note creation is Cloudflare-blocked, hence this Mac-driven path.
module Substack
  module Blizzard
    class ScheduledReposter
      include ServiceInterface

      arguments :base_url, :username, :password, limit: 5, commit: true, substack: nil

      PACING = 5 # seconds between posts, to stay gentle on Substack

      Result = Struct.new(:posted, :failed, :skipped, keyword_init: true)

      def execute
        @substack ||= Substack::Client.new
        posted  = []
        failed  = []
        skipped = []

        claimed_groups.each do |group|
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

      def claimed_groups
        if @commit
          JSON.parse(post("/admin/substack-blizzard/scheduled/claim.json", limit: @limit.to_i))
        else
          JSON.parse(get("/admin/substack-blizzard/scheduled-due.json?limit=#{@limit.to_i}"))
        end
      end

      def repost(group)
        post_url = group["post_url"]
        # The post becomes a preview-card attachment, so drop the inline URL from
        # the body to avoid a duplicate truncated text link.
        body           = NoteParser.strip_post_url(group["body_json"], post_url)
        attachment_ids = post_url.present? ? [@substack.create_attachment(post_url)].compact : []

        created = NoteParser.comment(@substack.create_note(body, attachment_ids: attachment_ids))
        record  = {
          "url"       => NoteParser.build_note_url(group["template_url"], created["id"]),
          "timestamp" => NoteParser.timestamp(created) || Time.current.utc.iso8601
        }
        confirm(group, record)
        record.merge("text" => group["text"])
      end

      def confirm(group, record)
        post("/admin/substack-blizzard/scheduled/confirm.json",
             categorization_id: group["categorization_id"],
             index:             group["index"],
             t:                 group["t"],
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
