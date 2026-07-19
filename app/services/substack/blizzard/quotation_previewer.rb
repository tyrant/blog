# frozen_string_literal: true

require "net/http"
require "json"

# Runs LOCALLY (residential IP, to clear Cloudflare): fetches a quotation note
# from prod and posts it to Substack as a real Note so it can be eyeballed exactly
# as it renders, then hands back its id/url for the caller to delete. Mirrors
# RepostTicker's prod-driving path; server-side note creation is Cloudflare-blocked.
module Substack
  module Blizzard
    class QuotationPreviewer
      include ServiceInterface

      arguments :base_url, :username, :password, id: nil, substack: nil

      def execute
        @substack ||= Substack::Client.new
        group = fetch
        return nil if group.blank?

        post_url = group["post_url"]
        body           = NoteParser.strip_post_url(group["body_json"], post_url)
        attachment_ids = post_url.present? ? [@substack.create_attachment(post_url)].compact : []

        created = NoteParser.comment(@substack.create_note(body, attachment_ids: attachment_ids))
        {
          "id"   => created["id"],
          "url"  => NoteParser.build_note_url(nil, created["id"]),
          "text" => group["text"]
        }
      end

      private

      def fetch
        path = "/admin/substack-blizzard/quotation/preview.json"
        path += "?id=#{@id}" if @id.present?
        parsed = JSON.parse(request(Net::HTTP::Get.new(uri(path))))
        parsed.is_a?(Hash) && parsed.present? ? parsed : nil
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
