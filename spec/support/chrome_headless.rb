# Control headless mode via HEADLESS env var (default: true for CI, configurable locally)
HEADLESS_CHROME = ENV.fetch('HEADLESS', 'true') == 'true'

RSpec.configure do |config|

  Capybara.register_driver :robspierre do |driver|

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless=new') if HEADLESS_CHROME
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1400,1400')

    Capybara::Selenium::Driver.new(driver, browser: :chrome, options: options)
  end

  config.before(:each, type: :system) { driven_by :robspierre }

  # Skip tests tagged :skip_headless when running in headless mode
  config.before(:each, :skip_headless) do
    skip 'Skipped in headless Chrome (hover events unreliable)' if HEADLESS_CHROME
  end
end
