# frozen_string_literal: true

class Comfy::Blog::PostsController < Comfy::Cms::BaseController

  include Comfy::Paginate

  def index
    scope =
      if params[:year]
        scope = @cms_site.blog_posts.published.for_year(params[:year])
        params[:month] ? scope.for_month(params[:month]) : scope
      else
        @cms_site.blog_posts.published
      end

    scope = scope.for_category(params[:category]) if params[:category]
    scope = scope.order(:published_at).reverse_order

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

    @cms_post =
      if params[:year] && params[:month]
        post_scope.where(year: params[:year], month: params[:month]).first!
      else
        post_scope.first!
      end
    @cms_layout = @cms_post.layout

    render layout: app_layout

  rescue ActiveRecord::RecordNotFound
    render cms_page: "/404", status: 404
  end

  private

  def app_layout
    return false unless @cms_layout
    @cms_layout.app_layout.present? ? @cms_layout.app_layout : false
  end

end
