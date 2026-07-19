# frozen_string_literal: true

require "net/http"
require "json"

# Runs LOCALLY (residential IP, to clear Cloudflare) driving a remote (prod)
# instance: asks prod for the next weighted repost (prod gates itself to one per
# interval), creates a fresh Substack Note for it, and confirms it back. Most
# ticks are no-ops (not yet time / nothing eligible). Server-side note creation is
# Cloudflare-blocked, hence this Mac-driven path.
module Substack
  module Blizzard
    class RepostTicker
      include ServiceInterface

      arguments :base_url, :username, :password, commit: true, substack: nil

      Result = Struct.new(:posted, :skipped, :failed, keyword_init: true)

      def execute
        @substack ||= Substack::Client.new
        posted  = []
        skipped = []
        failed  = []

        group = claim
        if group.blank?
          # no-op tick
        elsif group["body_json"].blank?
          skipped << { "text" => group["text"], "reason" => "no body_json" }
        elsif !@commit
          posted << { "text" => group["text"], "dry_run" => true }
        else
          begin
            posted << repost(group)
          rescue => e
            failed << { "text" => group["text"], "error" => e.message }
          end
        end

        Result.new(posted: posted, skipped: skipped, failed: failed)
      end

      private

      def claim
        body = @commit ? post("/admin/substack-blizzard/repost/tick.json", {}) : get("/admin/substack-blizzard/repost/preview.json")
        parsed = JSON.parse(body)
        parsed.is_a?(Hash) ? parsed : nil
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
        # Quotation reposts aren't tracked against an entry, so there's nothing
        # to confirm back.
        confirm(group, record) if group["categorization_id"].present?
        record.merge("text" => group["text"])
      end

      def confirm(group, record)
        post("/admin/substack-blizzard/repost/confirm.json",
             categorization_id: group["categorization_id"],
             uid:               group["uid"],
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
