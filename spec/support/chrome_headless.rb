RSpec.configure do |config|

  Capybara.register_driver :robspierre do |driver|
    Capybara::Selenium::Driver.new driver,
      browser: :chrome,
      capabilities: [Selenium::WebDriver::Chrome::Options.new(
        args: %w[headless]
      )]
  end

  config.before(:each, type: :system) { driven_by :robspierre }
end
