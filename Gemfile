source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby File.read('.ruby-version').strip

gem 'rails', '~> 6.1.4', '>= 6.1.4.1'
gem 'pg'
gem 'puma', '~> 5.0'
gem 'webpacker', '~> 5.4'
gem 'jbuilder', '~> 2.7'
# gem 'redis', '~> 4.0'
# gem 'bcrypt', '~> 3.1.7'

gem 'image_processing', '~> 1.2'

gem 'bootsnap', '>= 1.4.4', require: false
gem 'dotenv-rails'
gem 'config'
gem 'view_component'
gem 'matrix' 

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'faker'
end

group :development do
  gem 'web-console', '>= 4.1.0'
  gem 'rack-mini-profiler', '~> 2.0'
  gem 'listen', '~> 3.3'
  gem 'spring'
  gem 'capistrano-rails'
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
