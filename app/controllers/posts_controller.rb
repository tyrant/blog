class PostsController < Comfy::Blog::PostsController

  def index
    @show_other_books = true
    @only_paid_books = true

    scope =
      if params[:year]
        scope = @cms_site.blog_posts.published.for_year(params[:year])
        params[:month] ? scope.for_month(params[:month]) : scope
      else
        @cms_site.blog_posts.published
      end
  
    scope = scope.for_category(params[:category]) if params[:category]
    scope = scope.includes(categorizations: :category).order(:published_at).reverse_order
  
    @blog_posts = comfy_paginate(scope, per_page: ComfyBlog.config.posts_per_page)
    render layout: ComfyBlog.config.app_layout
  end

  def show
    post_scope = @cms_site.blog_posts.published.where(slug: params[:slug])

    if post_scope.empty?
      post_id = PaperTrail::Version.where(item_type: "Comfy::Blog::Post")
        .where('object LIKE ?', "%slug: #{params[:slug]}%")
        .order(created_at: :desc)
        .first!
        &.item_id
      post = @cms_site.blog_posts.published.find(post_id)

      redirect_to comfy_blog_post_path(year: post.year, month: post.month, slug: post.slug) and return
    end

    @cms_post = if params[:year] && params[:month]
        post_scope.where(year: params[:year], month: params[:month])
      else
        post_scope
      end.first!
    @cms_layout = @cms_post.layout

    years = @cms_site.blog_posts.published
                     .where.not(id: @cms_post.id)
                     .distinct
                     .pluck(Arel.sql("EXTRACT(YEAR FROM published_at)::int"))
                     .sort
                     .reverse

    @yearly_random_posts = years.map do |year|
        @cms_site.blog_posts.published
                .where.not(id: @cms_post.id)
                .where(Arel.sql("EXTRACT(YEAR FROM published_at)::int = ?"), year)
                .order(Arel.sql("RANDOM()"))
                .first
      end.compact || []


    render layout: app_layout

  rescue ActiveRecord::RecordNotFound
    render cms_page: "/404", status: 404
  end

  def prev_nek
    @cms_post = Comfy::Blog::Post.includes(categorizations: :category)
                                 .find(params[:id])
    @possibly_all_categories = [
        nil,
        *Comfy::Cms::Category.public_names
                             .nsfw_banished(@nsfw_options['banish'])
                             .order(:label)
      ]
  end
end
