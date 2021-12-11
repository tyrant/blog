module MoreComfyBlogPostMethods

  # We would like the immediate prev/nek posts straddling this post, ordered by published_at.
  # These posts *might* be filtered by category.
  def prev_nek(for_category: nil)

    # Yeah, I realise #first is brittle, but I doubt I'll be using this app for 
    # multiple Sites.
    published = Comfy::Cms::Site.first.blog_posts.published
    possibly_categorised = if !for_category.nil?
        published.for_category(for_category.label)
      else
        published
      end

    {
      prev: possibly_categorised.where('comfy_blog_posts.published_at < ?', self.published_at)
        .order('published_at desc').limit(1).first,
      nek: possibly_categorised.where('comfy_blog_posts.published_at > ?', self.published_at)
        .order('published_at asc').limit(1).first
    }
  end
end