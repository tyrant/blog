# frozen_string_literal: true

# Chrome 158+ rejects Capybara's between-tests storage reset,
# `Storage.clearDataForOrigin` with origin "*" ("invalid argument: * is not a
# valid URL"), so every system example errored in teardown. Capybara 3.40.0 is
# the latest release and still sends it; upstream fixes are open as
# teamcapybara/capybara#2867 and #2868. This mirrors #2868: keep the "*" call
# for older Chromes, and when it's rejected, clear all cookies plus the local
# storage of the page the test ended on.
#
# Limited to Capybara <= 3.40.0 — on upgrading, check whether the release fixed
# reset! and delete this file if so.
module CapybaraChromeResetPatch
  def reset!
    @origin_before_reset = origin_before_reset if @browser
    super
  end

  private

  def execute_cdp(cmd, params = {})
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError
    raise unless cmd == 'Storage.clearDataForOrigin' && params[:origin] == '*'

    super('Network.clearBrowserCookies')
    return unless @origin_before_reset && params[:storageTypes].to_s.include?('local_storage')

    super('Storage.clearDataForOrigin', origin: @origin_before_reset, storageTypes: 'local_storage')
  end

  def origin_before_reset
    uri = URI.parse(current_url.to_s)
    "#{uri.scheme}://#{uri.host}:#{uri.port}" if %w[http https].include?(uri.scheme) && uri.host
  rescue StandardError
    nil # a dead or about:blank tab has no storage worth clearing
  end
end

if Gem::Version.new(Capybara::VERSION) <= Gem::Version.new('3.40.0')
  Capybara::Selenium::Driver::ChromeDriver.prepend(CapybaraChromeResetPatch)
end
