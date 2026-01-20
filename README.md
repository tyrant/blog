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
Either that or `bin/dev`. Not `be bin/dev`! Foreman doesn't play nicely with
Bundler. See Foreman's docs re why.


## Prod dependencies

Now that we're on Rails 8, among other libraries, Prod requires libvps42 to do 
its Blob variant resizing. 


## Rails Credentials

Took a bit to figure this stuff out. Here's the deal. You've got per-env creds, stored in config/credentials/*.yml.enc, and an overall app creds file, in config/credentials.yml.enc. 

### Keys

Each is accompanied by a file containing its corresponding encryption key.

Two issues are extra-paramount:
* FOR GOD'S SAKE GITIGNORE THESE KEY FILES :scream:
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


## Comfortable Mexican Sofa

There is a gem. [https://github.com/comfy/comfortable-mexican-sofa](https://github.com/comfy/comfortable-mexican-sofa). It's a CMS for Rails. It's been around for years and years. I first embraced it when building nzsf.org.nz back in 2014, using Rails 4. It's been great.

You may notice that its GitHub page proudly proclaims support for Rails 5.2. At time of writing, 2026-01-19, Rails's latest-stable version is 8.1.1. Yyyyeah. It's been abandoned. Its [most recent commit](https://github.com/comfy/comfortable-mexican-sofa/commit/8f7e425a06aca9cfa8e21de6b7a10669c8495fc3) was on 2020-04-04. Huh. Maybe Covid got them.

CMS had okay-ish compatibility with Rails 6 but not 7, so until late 2025 I'd kept this app at Rails 6.x. For years. This quite spectacularly hamstrung other upgrades like fleeing squeeing from Webpack. Ultimately I bit the bullet and forked both CMS and an extension, [ComfyBlog](https://github.com/comfy/comfy-blog); got both my local forks up to Rails 8 standards; got this app itself upgraded to Rails 8; chunked through quite a lot of nonessential-yet-fab upgrades; and finally just refactored both CMS and ComfyBlog into this app as if they'd always been part of the core app itself.

