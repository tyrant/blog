RSpec.configure do |config|

  Capybara.register_driver :robspierre do |driver|

    options = Selenium::WebDriver::Chrome::Options.new
    # options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1400,1400')

    Capybara::Selenium::Driver.new(driver, browser: :chrome, options: options)
  end

  config.before(:each, type: :system) { driven_by :robspierre }
end
