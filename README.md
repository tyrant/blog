# README

## Check out my blog

I love writing. I've authored several novels and a gazillion blog posts. It's a joy.

I'm also a web dev. Oodles of authors have personal websites. Why wouldn't I? Like, a proper web app, not some Wordpress cruft. No disrespect to Wordpress itself, mind you, nor to those authors using it. It absolutely has its place. And most authors are proudly non-techies. For them, Wordpress works. But come on. Here's me purporting to be a mega-nerd. Why wouldn't I build my own app from the ground up?

In 2022, I'd caught Covid, and had a couple of weeks free. So I started cranking out this baby.

It's your classic Rails/Postgres stack. I kicked off with Rails 6, upgrading to 8 in mid-2025. Why so late? Read the Comfortable Mexican Sofa section below for more.


## [Foreman](https://github.com/ddollar/foreman) and Procfiles

This is your hourly reminder that you run your Procfile contents thusly:
```
foreman start -f Procfile.dev
```
Either that or `bin/dev`. Not `bundle exec bin/dev`! Foreman doesn't play nicely with
Bundler. See [Foreman's docs](https://github.com/ddollar/foreman/wiki/Don't-Bundle-Foreman) re why.


## Prod dependencies

Now that we're on Rails 8: among other libraries, Prod requires libvips42 to do 
its Blob variant resizing. It's a non-Ruby dependency of the `image_processing` gem.
Install it manually on Prod thusly:
```
sudo apt install libvips42
```


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

But not Production! Turns out Production is a special case. Its creds file doesn't inherit from credentials.yml. All its contents must be in only that file. Including secret_key_base. Make sure this exists within. Otherwise you'll never hear the end of it.


## Comfortable Mexican Sofa

There is a gem. [Comfortable Mexican Sofa](https://github.com/comfy/comfortable-mexican-sofa), or Comfy for short. It's a CMS for Rails. It's been around for years and years. I first embraced it when building nzsf.org.nz back in 2014, using Rails 4. Historically, it's been great. Historically.

You may notice that its GitHub page proudly proclaims support for Rails 5.2. At time of writing, 2026-01-19, Rails's latest-stable version is 8.1.1. Yyyyeah. Comfy has been abandoned. Its [most recent commit](https://github.com/comfy/comfortable-mexican-sofa/commit/8f7e425a06aca9cfa8e21de6b7a10669c8495fc3) was on 2020-04-04. Huh. Maybe Covid got them.

Comfy, and an extension, [ComfyBlog](https://github.com/comfy/comfy-blog), have both had okay-ish compatibility with Rails 6, but not 7. I'd attempted to contact ComfyBlog's authors [by raising various GitHub Issues](https://github.com/comfy/comfy-blog/issues/88), but alas, crickets.

So until late 2025, these had kept this app at Rails 6.x. This quite spectacularly hamstrung other upgrades like fleeing squeeing from Webpack (see below). Ultimately I bit the bullet and forked both Comfy and ComfyBlog; got both my local forks up to Rails 8 standards; got this app itself upgraded to Rails 8; chunked through quite a big backlog of nonessential-yet-fab upgrades; and finally just refactored both Comfy and ComfyBlog into this app as if they'd always been part of the core app itself. Done. I've got no plans to ever use Comfy elsewhere, so I don't mind spurning modularity and embracing monolith-arity.


## Asset Pipeline and client-side shenanigans

Good lord I am relieved to be rid of both [Webpack](https://webpack.js.org/), the pure-JS asset/JS/CSS/image compiler, and [Webpacker](https://github.com/rails/webpacker), its Ruby/Rails wrapper. At mission start in 2022, Rails 6 came default with both, so I figured why not.

I'll tell you for why not. First, they're ungoogleable. Any tech has its teething problems. But attempting to google any tech issue related to Webpack not unreasonably returns a gazillion Node-only-flavoured results. Not Rails. Makes sense I suppose, as Webpack's prime stomping ground is Node. But this buries any Rails-flavoured Webpack content. Additionally, what few Rails results I could find were seldom clear on where Webpack ends and Webpacker begins. 

Second, even when they functioned okay, I found them oddly and uniquely fragile. It's harder to put my finger on this, but in daily usage, Webpack/er seemed bafflingly brittle in ways few other techs or libraries did. They'd cease working at inopportune moments and resist debugging in subtly insidious ways. Again, any tech has teething issues. All are imperfect. Some are easier to fix than others. And a major, major lubricant to hassle-free debugging is really specific and actionable error messages. Webpack produces few.

So a big part of the Rails 6->8 upgrade was banishing Webpacker forever, and embracing [esbuild](https://esbuild.github.io/), [jsbundling-rails](https://github.com/rails/jsbundling-rails), [cssbundling-rails](https://github.com/rails/cssbundling-rails), and [tailwindcss-rails](https://github.com/rails/tailwindcss-rails).


### Quick summary

#### Compiling Javascript

Our main app JS/TS files are at:
* app/javascript/*
* app/components/*_controller.ts

They're very much a WIP and I'm constantly amending them.

They're hoicked into a single file via regular ol' ES6 directives at app/javascript/application.js. esbuild receives this (config/esbuild.config.js, line 8) and bundles into app/assets/builds/application.js. It's used by the main blog app.

Comfy's JS app files are at: `app/assets/javascripts/comfy/admin/cms/*.js`. They seldom change. Comfy's JS dependencies are at: `app/assets/javascripts/comfy/vendor/*.js`. They almost never change. They're used by ComfyAdmin.

esbuild receives the former at `app/javascripts/comfy_admin.js` (regular ol' ES6 directives) (config/esbuild.config.js, line 9) and bundles this into `app/assets/builds/comfy_admin.js`.

Now, the latter dependencies. Yes. esbuild could absolutely squirt them into app/assets/build ... but for never-changing static files? Going to all that trouble is almost certainly overkill. Instead? Run `ruby bundle_assets.rb`. This performs a one-off bundle from app/assets/javascripts/comfy/vendor/*.js into app/assets/builds/comfy_vendor.js.

Now we've got three JS build files ready for pipeline-yoinking: `app/assets/builds/application.js`, `app/assets/builds/comfy_admin.js`, and `app/assets/builds/comfy_vendor.js`.


#### Compiling CSS

As of 2026, this app uses [Tailwind CSS v4](https://tailwindcss.com/), which is fully CSS-native — no `tailwind.config.js` needed. All configuration lives in `app/assets/stylesheets/application.tailwind.css` via `@import`, `@plugin`, `@source`, `@theme`, and `@variant` directives.

These are live-reloaded by Procfile.dev's line 3: `css: yarn build:css:watch`, which runs the Tailwind CLI and outputs `app/assets/builds/application.css`, ready for pipeline-yoinking by `app/views/layouts/application.html.erb`.


#### Asset Pipeline

The regular ol' asset pipeline makes all JS/CSS builds at app/assets/builds/* yoinkable from the browser, via view-file helpers. Same with images. Propshaft handles this.


## Medium Sync

This was all Claude. My word.

Okay. `app/services/medium/post_syncer.rb` mirrors blog posts to Medium using browser automation (Selenium + Chrome DevTools Protocol). It manipulates Medium's Draft.js editor via ClipboardEvent pastes, image drag-and-drop, and keyboard shortcuts.

### How it works

The sync uses a **two-phase Chrome launch** to work around Cloudflare's Turnstile bot detection:

1. **Phase 1** — Chrome launches WITHOUT `--remote-debugging-port` so `navigator.webdriver` is `false`. It loads `medium.com` to earn/renew a `cf_clearance` cookie (~30 min validity). On headless servers, `xvfb-run` provides a virtual display so Chrome runs in full headed mode — Cloudflare cannot distinguish this from a real display.
2. **Phase 2** — Chrome relaunches WITH `--remote-debugging-port` (also via `xvfb-run` on servers) and navigates directly to the editor URL, skipping medium.com's homepage entirely so Turnstile never re-runs.

In development, Chrome opens visibly. In production, Chrome runs inside a virtual framebuffer (`xvfb`).

### Configuration

Sync settings (title template, content template, link template, footer HTML) are managed via the `MediumSyncConfig` model, editable in ComfyAdmin.

The `ROOT_URL` environment variable (set in `.env` / `.env.production`) drives `default_url_options` so that relative image URLs resolve correctly in all environments.

### Production setup

Chrome and xvfb must be installed on the production server:

```bash
sudo apt install -y google-chrome-stable xvfb
```

The `selenium-webdriver` gem handles communication via CDP — no separate chromedriver binary is needed. xvfb provides a virtual display so Chrome can run in headed mode on a headless server, bypassing Cloudflare's bot detection of `--headless`.

**One-time login:** Before the first production sync, you must establish a Medium login session in the Chrome profile. Run:

```bash
# SSH into the server with a tunnel for Chrome DevTools:
ssh -L 9222:127.0.0.1:9222 noob@mikeyclarke.co.nz

# Run the setup task:
cd /home/noob/blog/current && RAILS_ENV=production bundle exec rake medium:setup
```

Then in your local Chrome, go to `chrome://inspect/#devices`, click **Configure...**, add `localhost:9222`, and click the **inspect** link on the remote medium.com page. This gives you a live interactive view of the server's Chrome — log in to Medium there. Press Enter in the SSH session when done (the task verifies the `uid` cookie was saved). Medium's session cookies persist for months in the Chrome profile at `tmp/medium_sync_chrome_profile/`.

### Triggering a sync

From ComfyAdmin's post edit page, click the "Sync to Medium" button. This calls `Medium::PostSyncer.execute(post_id:)` which handles title, subtitle, body content, images, link paragraph, footer, and autosave confirmation.


## ActiveStorage and AWS

[TODO]

