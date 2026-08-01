# frozen_string_literal: true

# Verifies the stored Substack session cookie with one cheap authenticated call
# and stamps the outcome on the config so the admin page can surface an expired
# session. Returns a Result whose status is :ok (valid), :auth_failed (expired —
# refresh the cookie), or :inconclusive (a non-auth error such as a network blip,
# where the stored health status is deliberately left unchanged).
module Substack
  class HealthCheck
    include ServiceInterface

    Result = Struct.new(:status, :message, keyword_init: true) do
      def ok?
        status == :ok
      end
    end

    arguments client: nil

    def execute
      @client ||= Substack::Client.new
      @client.verify_session
      SubstackSyncConfig.instance.record_check!(healthy: true)
      Result.new(status: :ok, message: "Session cookie is valid.")
    rescue Substack::Client::AuthError => e
      SubstackSyncConfig.instance.record_check!(healthy: false, error: e.message)
      Result.new(status: :auth_failed, message: e.message)
    rescue Substack::Client::Error => e
      Result.new(status: :inconclusive, message: e.message)
    end
  end
end
