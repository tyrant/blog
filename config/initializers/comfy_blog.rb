# frozen_string_literal: true

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
