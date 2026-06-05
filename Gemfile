source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby File.read('.ruby-version').strip

gem 'rails', '~> 8.0'
gem 'pg', '~> 1.5'
gem 'puma', '~> 6.0'
gem 'propshaft'
gem 'jsbundling-rails'
gem 'cssbundling-rails'
gem 'jbuilder', '~> 2.7'

gem 'image_processing', '~> 1.2'
gem 'bootsnap', '>= 1.16.0', require: false
gem 'view_component'
gem 'matrix'
gem 'turbo-rails'

# https://github.com/net-ssh/net-ssh/issues/565
gem 'ed25519'
gem 'bcrypt_pbkdf'
gem 'net-ssh', '>= 7.2.0'  # OpenSSL 3.0 compatibility

# https://stackoverflow.com/questions/70500220/rails-7-ruby-3-1-loaderror-cannot-load-such-file-net-smtp
gem 'mail', '>= 2.8.0'

gem 'mailkick'
gem 'base64'
gem 'ostruct' # removed from Ruby 4.0 default gems; needed by sshkit/capistrano
gem 'jwt'
gem 'service_interface'

gem 'aws-sdk-s3', require: false
gem 'active_storage_validations'

gem 'dotenv-rails'
gem 'paper_trail'

group :development, :test do
  gem 'debug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'faker'
end

group :development do
  gem 'web-console', '>= 4.1.0'
  gem 'rack-mini-profiler', '~> 3.0'
  gem 'listen', '~> 3.8'
  # gem 'spring' # Not needed in Rails 8
  gem 'capistrano-rails', '~> 1.6'
  gem 'capistrano-rbenv'
  gem "capistrano-bundler"
  gem "capistrano-passenger", '~> 0.2.0'
  #gem 'capistrano-local-precompile', '~> 1.2.0', require: false
  gem 'letter_opener'
  gem 'letter_opener_web'
  gem 'mutex_m'
end

gem 'selenium-webdriver', '>= 4.0'

group :test do
  gem 'capybara', '>= 3.39'
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails', '~> 6.4'
  gem 'simplecov', require: false
  gem 'simplecov-html', require: false
  gem 'database_cleaner-active_record'
  gem 'shoulda-matchers', '~> 6.0'
end

gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# CMS dependencies (formerly from comfortable_mexican_sofa gem)
gem 'rails-i18n'
gem 'comfy_bootstrap_form'
gem 'active_link_to'
gem 'kramdown'
gem 'jquery-rails'
gem 'haml-rails'

gem 'nokogiri'
gem 'whenever'
gem 'kaminari'

# Use Redis for Action Cable
gem 'redis', '>= 4.0.1'
