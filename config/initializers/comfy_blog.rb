# frozen_string_literal: true

# Load Blog library (now integrated into the app)
require_relative "../../lib/comfy_blog"

# Set up view hooks and site extensions
ComfortableMexicanSofa::ViewHooks.add(:navigation, "/comfy/admin/blog/partials/navigation")

Rails.application.config.to_prepare do
  Comfy::Cms::Site.include ComfyBlog::CmsSiteExtensions
end

ComfyBlog.configure do |config|
  # application layout to be used to index blog posts
  config.app_layout = 'layouts/application'

  # Number of posts per page. Default is 10
  config.posts_per_page = 12
end

Rails.application.config.to_prepare do
  Comfy::Blog::Post.instance_eval { include ComfyBlogPostMethods }
  Comfy::Cms::Category.instance_eval { include ComfyCmsCategoryMethods }
end
