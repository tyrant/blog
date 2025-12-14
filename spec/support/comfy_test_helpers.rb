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
    ComfortableMexicanSofa::AccessControl::AdminAuthentication.username = "username"
    ComfortableMexicanSofa::AccessControl::AdminAuthentication.password = "password"
  end

  def reset_blog_config
    ComfyBlog.configure do |config|
      config.posts_per_page   = 10
      config.app_layout       = "comfy/blog/application"
      config.public_blog_path = "blog"
    end
  end

  def http_auth_headers
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(
        ComfortableMexicanSofa::AccessControl::AdminAuthentication.username,
        ComfortableMexicanSofa::AccessControl::AdminAuthentication.password
      )
    }
  end
end

RSpec.configure do |config|
  config.include ComfyTestHelpers
end
