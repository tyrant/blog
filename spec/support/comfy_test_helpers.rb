# frozen_string_literal: true

module ComfyTestHelpers
  def reset_cms_config
    ComfortableMexicanSofa.configure do |config|
      config.cms_title            = "ComfortableMexicanSofa CMS Engine"
      config.admin_auth           = "ComfortableMexicanSofa::AccessControl::AdminAuthentication"
      config.admin_authorization  = "ComfortableMexicanSofa::AccessControl::AdminAuthorization"
      config.public_auth          = "ComfortableMexicanSofa::AccessControl::PublicAuthentication"
      config.public_authorization = "ComfortableMexicanSofa::AccessControl::PublicAuthorization"
      config.admin_route_redirect = ""
      config.enable_seeds         = false
      config.seeds_path           = File.expand_path("db/cms_seeds", Rails.root)
      config.revisions_limit      = 25
      config.locales              = { "en" => "English", "es" => "Español" }
      config.admin_locale         = nil
      config.admin_cache_sweeper  = nil
      config.allow_erb            = false
      config.allowed_helpers      = nil
      config.allowed_partials     = nil
      config.allowed_templates    = nil
      config.hostname_aliases     = nil
      config.reveal_cms_partials  = false
      config.public_cms_path      = nil
      config.page_to_json_options = { methods: [:content], except: [:content_cache] }
    end
  end

  def reset_blog_config
    ComfyBlog.configure do |config|
      config.posts_per_page   = 10
      config.app_layout       = "comfy/blog/application"
      config.public_blog_path = "blog"
    end
  end

  # Restore config to actual app settings (for system tests)
  def restore_app_config
    ComfyBlog.configure do |config|
      config.posts_per_page   = 12
      config.app_layout       = "layouts/application"
      config.public_blog_path = "blog"
    end
  end

  # Request specs: signs this example's session in as admin (via a recovery
  # link, the same path a locked-out admin uses) the first time it's called,
  # and returns the headers for an admin request. Used as
  # `get path, headers: admin_headers`, so examples that never call it stay
  # signed out.
  def admin_headers
    unless @admin_signed_in
      get comfy_admin_recover_path(token: AdminRecovery.token)
      @admin_signed_in = true
    end
    {}
  end

  # System specs: sign the browser in as admin, on the same host the specs then
  # visit (so the session cookie applies).
  def sign_in_admin_in_browser
    visit "http://#{Capybara.server_host}:#{Capybara.server_port}#{comfy_admin_recover_path(token: AdminRecovery.token)}"
  end
end

RSpec.configure do |config|
  config.include ComfyTestHelpers

  # Restore app config before system tests to prevent pollution from unit tests
  config.before(:each, type: :system) do
    restore_app_config
  end
end
