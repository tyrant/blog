# frozen_string_literal: true

require 'webmock/rspec'

# Allow localhost so Capybara/Selenium system specs keep working; block other
# real HTTP so external calls (e.g. Substack) must be stubbed.
WebMock.disable_net_connect!(allow_localhost: true)
