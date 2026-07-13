# frozen_string_literal: true

class Comfy::Admin::TagsController < Comfy::Admin::Cms::BaseController

  before_action :load_tag, only: %i[edit update destroy]

  def index
    @tags = comfy_paginate(Tag.alphabetical.left_joins(:blog_post_tags)
      .select("tags.*, COUNT(blog_post_tags.id) AS posts_count").group("tags.id"), per_page: 50)
  end

  def new
    @tag = Tag.new
  end

  def create
    Tag.create!(tag_params)
    flash[:success] = "Tag created."
    redirect_to action: :index
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:danger] = e.record.errors.full_messages.to_sentence
    @tag = e.record
    render action: :new
  end

  def edit
  end

  def update
    @tag.update!(tag_params)
    flash[:success] = "Tag updated."
    redirect_to action: :index
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:danger] = e.record.errors.full_messages.to_sentence
    render action: :edit
  end

  def destroy
    # Deleting a tag removes it locally only; suppress the per-link mirror so a
    # vocabulary edit doesn't bulk-unassign the tag across every Substack post.
    BlogPostTag.without_mirror { @tag.destroy }
    flash[:success] = "Tag deleted."
    redirect_to action: :index
  end

  protected

  def load_tag
    @tag = Tag.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = "Tag not found."
    redirect_to action: :index
  end

  def tag_params
    params.require(:tag).permit(:name)
  end

end
