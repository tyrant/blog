# Apologies for the sliiiightly unorthodox loading pattern here, but
# this module is loaded into this Blog app via config/application.rb,
# in an after_initialize hook, using class_eval.

module ComfyBlogPostMethods

  attr_accessor :posts

  def nsfw?
    categories.include? Comfy::Cms::Category.find_by(label: 'NSFW')
  end

  # We would like the immediate prev/nek posts straddling this post,
  # ordered by published_at.
  # { prev: post_preceding_self, nek: post_following_self }
  # Preceding/following posts may first be filtered by category.
  # We also have a NSFW filter boolean flag doohickey. Yes, NSFW is a category
  # too, but NSFW must be explicitly opt-in: regular filtering ain't good enough.
  # See the method comments for more.
  # Yeah, I realise calling this across multiple Categories is an N+1 bug, but it's 
  # honestly not that big a performance hit. In practice, Posts generally don't 
  # have vast Category counts.
  def prev_nek(category: nil, nsfw: false)
    # I realise #first is brittle, but I doubt I'll be using this app for 
    # multiple Sites.
    @posts = Comfy::Cms::Site.first.blog_posts.published

    @posts = if category.present?
        if nsfw
          @posts.for_category(category.label, 'NSFW')
        else 
          @posts.for_category(category.label)
            .where("NOT EXISTS(
              SELECT NULL FROM comfy_cms_categorizations
                WHERE comfy_blog_posts.id = comfy_cms_categorizations.categorized_id
                  AND comfy_cms_categorizations.category_id = (
                    SELECT id FROM comfy_cms_categories WHERE label = 'NSFW'
                  )
              )")
        end
      else
        if nsfw
          @posts
        else
          @posts.joins(:categorizations)
            .where("comfy_cms_categorizations.categorized_type = 'Comfy::Blog::Post'")
            .where("NOT EXISTS(
              SELECT NULL FROM comfy_cms_categorizations
                WHERE comfy_blog_posts.id = comfy_cms_categorizations.categorized_id
                  AND comfy_cms_categorizations.category_id = (
                    SELECT id FROM comfy_cms_categories WHERE label = 'NSFW'
                  )
              )")
        end
      end
    
    {
      prev: @posts
        .where('comfy_blog_posts.published_at < ?', self.published_at)
        .order('published_at desc')
        .limit(1).first,
      nek: @posts
        .where('comfy_blog_posts.published_at > ?', self.published_at)
        .order('published_at asc')
        .limit(1).first
    }
  end
end