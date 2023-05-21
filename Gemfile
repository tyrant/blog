source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby File.read('.ruby-version').strip

gem 'rails', '~> 6.1.4', '>= 6.1.4.1'
gem 'pg'
gem 'puma', '~> 5.0'
gem 'webpacker', '~> 5.4'
gem 'jbuilder', '~> 2.7'
gem 'tailwindcss-rails'

gem 'image_processing', '~> 1.2'
gem 'bootsnap', '>= 1.4.4', require: false
gem 'view_component'
gem 'matrix'
gem 'turbo-rails'

# https://github.com/net-ssh/net-ssh/issues/565
gem 'ed25519'
gem 'bcrypt_pbkdf'

# https://stackoverflow.com/questions/70500220/rails-7-ruby-3-1-loaderror-cannot-load-such-file-net-smtp
gem 'mail', '~> 2.8.0'

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'faker'
end

group :development do
  gem 'web-console', '>= 4.1.0'
  gem 'rack-mini-profiler', '~> 2.0'
  gem 'listen', '~> 3.3'
  gem 'spring'
  gem 'capistrano-rails', '~> 1.6'
  gem 'capistrano-rbenv'
  gem "capistrano-bundler"
  gem "capistrano-passenger", '~> 0.2.0'
end

group :test do
  gem 'capybara', '>= 3.26'
  gem 'selenium-webdriver'
  gem 'webdrivers'
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'database_cleaner-active_record'
end

gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
gem "comfortable_mexican_sofa", "~> 2.0.0"

# https://github.com/comfy/comfy-blog/issues/88
gem "comfy_blog", "~> 2.0.0", git: 'https://github.com/comfy/comfy-blog.git', branch: 'master'
gem 'nokogiri'
gem 'whenever'
gem 'kaminari'

# Use Redis for Action Cable
gem 'redis', '~> 4.0'
