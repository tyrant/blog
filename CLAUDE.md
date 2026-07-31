# Project: Mikey Clarke's Blog

Personal blog built on Rails with ComfortableMexicanSofa CMS (merged into app, not a gem).

## Tech Stack

- **Framework**: Rails 8.0, Ruby 4.0.5
- **Database**: PostgreSQL
- **Image Processing**: libvips via ActiveStorage (not MiniMagick)
- **Testing**: RSpec, FactoryBot, Capybara, Shoulda Matchers
- **Deployment**: Capistrano to production server (168.144.167.177, DigitalOcean), Phusion Passenger

## Architecture

- **CMS**: ComfortableMexicanSofa merged directly into `app/` and `lib/comfortable_mexican_sofa/`
- **Blog**: ComfyBlog merged directly into `app/` and `lib/comfy_blog/`
- These are NOT external gems - all code lives in this repo
- Zeitwerk ignores: `lib/comfortable_mexican_sofa`, `lib/comfy_blog`, `lib/generators`

## Code Style

- Use `# frozen_string_literal: true` in all Ruby files
- No trailing whitespace
- 2-space indentation for Ruby
- Prefer descriptive variable names over abbreviations
- Use `create :site`, `create :layout`, `create :page` for factories


## RSpec Conventions
- One assertion/expectation per it{} block
- Keep it{} blocks short and focused - all code not part of it{} to be moved to before{} or let{}
- Use shared examples for common patterns
- Use `expect{}` for exception expectations
- No spaces around `eq`: `expect(foo).to eq bar`
- No spaces around `and`: `expect(foo).to eq bar and expect(baz).to eq qux`
- No spaces around `not`: `expect(foo).to_not eq bar`
- No spaces around `be`: `expect(foo).to be bar`
- No spaces around `be_an_instance_of`: `expect(foo).to be_an_instance_of Bar`

### File Structure
```
spec/
├── factories/          # FactoryBot factories
├── fixtures/files/     # Test image files (jpg, heic, heif)
├── models/            # Model specs
├── requests/          # Request/controller specs
├── support/           # Helpers, shared examples
└── system/            # Capybara system tests
```

### Spec Organization
Group specs in this order:
1. `describe 'associations'`
2. `describe 'validations'`
3. `describe 'callbacks'` (if applicable)
4. `describe '#instance_method'`
5. `describe '.class_method'`
6. `describe 'scopes'`

### Factories
- CMS models: `create :site`, `create :layout`, `create :page`
- Blog models: `create :post`, `create :category`, `create :categorization`
- Files: `create :comfy_cms_file, site: site, file: fixture_file`

### System Tests
- Headless Chrome by default (`HEADLESS=true`)
- Run with visible browser: `HEADLESS=false bundle exec rspec spec/system`
- Tag unreliable hover tests with `:skip_headless`

## Image Handling

### Variants (libvips syntax)
```ruby
# Correct (Rails 8 / libvips)
file.attachment.variant(resize_to_fill: [200, 150])

# Wrong (MiniMagick / ImageMagick)
file.attachment.variant(combine_options: { resize: "200x150^" })
```

### HEIC Support
- HEIC/HEIF files are auto-converted to JPEG on upload
- Handled in `Comfy::Cms::File#process_attachment`

## Configuration

### CMS Site
- Production hostname: `mikeyclarke.co.nz` (with port if needed)
- Development hostname: `localhost:3000`
- Blog path: `/blog`

### ComfyBlog Config
```ruby
ComfyBlog.config.posts_per_page   = 12
ComfyBlog.config.app_layout       = "layouts/application"
ComfyBlog.config.public_blog_path = "blog"
```

## Common Tasks

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/comfy/cms/file_spec.rb

# Run system tests with visible browser
HEADLESS=false bundle exec rspec spec/system

# Deploy to production
cap production deploy

# Rails console on production (user runs SSH commands themselves — see Deployment / Ops)
ssh noob@168.144.167.177 "cd ~/blog/current && RAILS_ENV=production bundle exec rails c"
```

## Deployment / Ops

- Auto-deploying is fine anytime — run `bundle exec cap production deploy` yourself as needed.
- After deploying, verify the commit was actually pushed (`git status`, `git log origin/mistress`) before reporting the deploy as successful — Capistrano ships the pushed commit, not local HEAD.
- Do NOT run direct SSH commands on the production server yourself (installing libraries/packages, arbitrary server ops, remote consoles) — the user reserves those. Prepare the exact command and hand it off to run.

## Environment / Shell Notes

- The bare `cap` command is a zsh wrapper unavailable in non-interactive shells — invoke deploys via `bundle exec cap` instead.

## Substack Integration

- Substack strips plain URLs from rendered output — verify URL fixes against Substack's actual rendered result rather than assuming they'll appear.
- Scope "Substack Notes" queries to Substack-linked posts only, not all posts.

## Don't

- Don't use `combine_options:` for image variants (ImageMagick syntax)
- Don't reference comfy gems in Gemfile (they're merged into app)
- Don't auto-run destructive commands without user approval
- Don't modify CMS/Blog core logic unless directly required for a fix
