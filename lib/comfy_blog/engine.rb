# frozen_string_literal: true

# This file is kept for backward compatibility but the engine functionality
# is now integrated directly into the Rails application.
# The Blog functionality is loaded via config/initializers/comfy_blog.rb

module ComfyBlog
  module CmsSiteExtensions
    extend ActiveSupport::Concern
    included do
      has_many :blog_posts,
        class_name: "Comfy::Blog::Post",
        dependent:  :destroy
    end
  end
end
