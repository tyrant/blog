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


## Foreman and Procfiles

This is your hourly reminder that you run your Procfile contents thusly:
```
foreman start -f Procfile.dev
```
Either that or `bin/dev`.

## Webpacker

Don't forget that we're using JS packs. To yoink our JS content into application_pack_tag+pals, Webpacker must run:

`$ bundle exec ./bin/webpack-dev-server`

Fire that shit up first, and thence all Stimulus controllers' content will remain current.


## Rails Credentials

Took a bit to figure this stuff out. Here's the deal. You've got multi-env creds, stored in config/credentials/*.yml.enc, and an overall app creds file, in config/credentials.yml.enc. 

### Keys

Each is accompanied by a file containing its corresponding encryption key.

Two issues are extra-paramount:
* FOR GOD'S SAKE GITIGNORE THESE FILES :scream:
* FOR GOD'S SAKE ADD THE KEYS THEMSELVES TO A PASSWORD MANAGER, DON'T LOSE THEM :scream: :scream:

Nail both, though? You're golden.

### Writing shit

You edit each file thusly:
```
EDITOR=nano bundle exec rails credentials:edit --environment [env-name-here]
```

Once decrypted, each file is simply your classic YAML goodness. Edit as you please, possibly like so:
```
# config/credentials.yml (once decrypted)
...
pg:
  username: username-goes-here
  password: password-goes-here
...
```

### Reading shit

Once added, you may then access their internals like so:
```
# config/database.yml
...
default: &default
  ...
  username: <%= Rails.application.credentials.pg[:username] %>
  password: <%= Rails.application.credentials.pg[:password] %>
...
```

Note the syntax. Hash keys, not method calls. Don't do `Rails.application.credentials.pg.username`! Rails's decryption creates method-calls for each YAML file's base-level keys ... and makes each of these methods return hashes. So `Rails.application.credentials.pg` returns a hash. This hash: `{ username: 'username-goes-here', password: 'password-goes-here }`.

### Per-environment inheritance/overrides

For development and test, any keys/values in config/credentials/*.yml will override those same keys and values in config/credentials.yml. So if you have different values for `Rails.application.credentials.pg[:password]` between development and test, you can use exactly the same method call in config/database.yml, and Rails will deduce and supply the correct value from the environment name.

But not production! Turns out production is a special case. Its creds file doesn't inherit from credentials.yml. All its contents must be in only that file. Including secret_key_base. Make sure this exists within. Otherwise you'll never hear the end of it.

