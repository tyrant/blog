require 'rake'

RSpec.configure do |config|

  # Basically just what it says on the tin. CMS requires data to run. Sites.
  # Doesn't exist? Fire up the ol' seed script and create it.
  config.before :suite do
    next if Comfy::Cms::Site.count > 0

    Rails.application.load_tasks # https://stackoverflow.com/a/10061815 :scream:
    Rake::Task['db:seed'].invoke
  end
end
