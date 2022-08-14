# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Dotenv and Settings

How cool is that? I've installed https://github.com/bkeepers/dotenv and https://github.com/rubyconfig/config. 

Add your environment variables to .env and friends. You don't need to use Foreman or anything like that to load them: Dotenv will handle that on its own. Config will then relay these to its Settings object.

Suppose .env contains `DBUSERNAME=foo`. Dotenv will then popuate `ENV['DBUSERNAME']` with `foo`, and `Settings.dbusername` will in turn contain `foo`. Easy peasy.

## Webpacker

Don't forget that we're using JS packs. To yoink our JS content into application_pack_tag+pals, Webpacker must run:

`$ bundle exec ./bin/webpack-dev-server`

Fire that shit up first, and thence all Stimulus controllers' content will remain current.