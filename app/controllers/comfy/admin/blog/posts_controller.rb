# frozen_string_literal: true

class Comfy::Admin::Blog::PostsController < Comfy::Admin::Cms::BaseController

  before_action :build_post, only: %i[new create]
  before_action :load_post,  only: %i[edit update destroy sync_to_medium sync_to_substack]
  before_action :authorize

  def index
    return redirect_to action: :new if @site.blog_posts.count.zero?

    posts_scope = @site.blog_posts
      .includes(:categories)
      .for_category(params[:categories])
      .order(published_at: :desc)
    @posts = comfy_paginate(posts_scope)
  end

  def new
    render
  end

  def create
    @post.save!
    flash[:success] = t(".created")
    redirect_to action: :edit, id: @post

  rescue ActiveRecord::RecordInvalid
    flash.now[:danger] = t(".create_failure")
    render action: :new
  end

  def edit
    @newer_post = @site.blog_posts.where('published_at > ?', @post.published_at).order(published_at: :asc).first
    @older_post = @site.blog_posts.where('published_at < ?', @post.published_at).order(published_at: :desc).first
    render
  end

  def update
    @post.update!(post_params)

    respond_to do |format|
      format.html do
        flash[:success] = t(".updated")
        redirect_to action: :edit, id: @post
      end
      format.json { render json: { success: true, updated_at: @post.updated_at } }
    end

  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.html do
        flash.now[:danger] = t(".update_failure")
        render action: :edit
      end
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  def destroy
    @post.destroy
    flash[:success] = t(".deleted")
    redirect_to action: :index
  end

  def sync_to_medium
    Medium::PostSyncer.execute(post_id: @post.id)
    render json: { success: true }
  rescue => e
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  def sync_to_substack
    SubstackPostSyncJob.perform_later(@post.id)
    flash[:success] = "Substack draft sync started for “#{@post.title}”."
    redirect_to edit_comfy_admin_blog_post_path(site_id: @post.site_id, id: @post.id)
  end

  def form_fragments
    @post = @site.blog_posts.find_by(id: params[:id]) || @site.blog_posts.new
    @post.layout = @site.layouts.find_by(id: params[:layout_id])

    render(
      partial:  "comfy/admin/cms/fragments/form_fragments",
      locals:   { record: @post, scope: :post },
      layout:   false
    )
  end

protected

  def load_post
    @post = @site.blog_posts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = t(".not_found")
    redirect_to action: :index
  end

  def build_post
    layout = (@site.blog_posts.order(:created_at).last.try(:layout) || @site.layouts.order(:created_at).first)
    @post = @site.blog_posts.new(post_params)
    @post.published_at ||= Time.zone.now
    @post.layout ||= layout
    @post.is_published = false if @post.new_record?
  end

  def post_params
    permitted = params.fetch(:post, {}).permit!
    return permitted unless request.format.json?

    # Autosave (JSON) re-submits the whole form, including the category side-panel as
    # it was at page load — and that panel can't even capture live #data edits. Drop it
    # so a periodic autosave can't clobber category / blizzard data written from another
    # tab (e.g. Substack Blizzard) since this page loaded. Explicit (HTML) Save still writes it.
    permitted.except(:category_ids, :categorizations_data).permit!
  end

end
