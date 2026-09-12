# frozen_string_literal: true

require "net/http"
require "json"

# Ruby counterpart to ~/Work/scripts/monitor_client.py — reports a run's outcome
# to the Script Monitor dashboard (https://monitor.mikeyclarke.co.nz/api/run).
# Best-effort: a reporting failure must never break the caller's actual work.
module MonitorClient
  URL = "https://monitor.mikeyclarke.co.nz/api/run"

  module_function

  def report(script:, status:, processed: 0, failed: 0, skipped: 0, errors: [])
    api_key = ENV["MONITOR_API_KEY"]
    return if api_key.blank?

    req = Net::HTTP::Post.new(URI(URL))
    req["Content-Type"] = "application/json"
    req["X-API-Key"] = api_key
    req.body = JSON.generate(
      script:    script,
      status:    status,
      processed: processed,
      failed:    failed,
      skipped:   skipped,
      errors:    errors,
      ran_at:    Time.now.utc.iso8601
    )

    Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
      http.request(req)
    end
  rescue => e
    Rails.logger.warn("[MonitorClient] report failed (non-fatal): #{e.message}")
  end
end
