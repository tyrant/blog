# frozen_string_literal: true

class Comfy::Admin::QuotationsController < Comfy::Admin::Cms::BaseController

  def index
    @quotation = SubstackQuotation.new
    load_quotations
  end

  def edit
    @quotation = SubstackQuotation.find(params[:id])
    load_quotations
    render :index
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = "Quotation not found."
    redirect_to comfy_admin_quotations_path
  end

  def create
    quotation = SubstackQuotation.new(quotation: params[:quotation], comment_url: params[:comment_url])
    quotation.populate_from_substack!
    quotation.save!
    SyncReviewsPageJob.perform_later
    flash[:success] = "Saved quotation#{quotation.author_name ? " by #{quotation.author_name}" : ""}."
  rescue => e
    flash[:danger] = "Could not save quotation: #{e.message}"
  ensure
    redirect_to comfy_admin_quotations_path
  end

  def update
    quotation = SubstackQuotation.find(params[:id])
    comment_changed = quotation.comment_url != params[:comment_url]
    quotation.assign_attributes(quotation: params[:quotation], comment_url: params[:comment_url])
    # The edit form submits post_url/post_title; assign only the keys sent so a
    # blurb-only edit (which omits them) doesn't blank the existing metadata.
    quotation.assign_attributes(params.permit(:post_url, :post_title))
    # Only re-hit Substack when the comment itself changed — a blurb-only edit
    # keeps the existing post/author metadata. Changing the comment re-resolves
    # (and overrides the manual post fields above); otherwise the manually-entered
    # post_url/post_title stand — needed when the comment is on a third-party note
    # whose post can't be auto-resolved.
    quotation.populate_from_substack! if comment_changed
    quotation.save!
    SyncReviewsPageJob.perform_later
    flash[:success] = "Quotation updated."
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = "Quotation not found."
  rescue => e
    flash[:danger] = "Could not update quotation: #{e.message}"
  ensure
    redirect_to comfy_admin_quotations_path
  end

  def destroy
    SubstackQuotation.find(params[:id]).destroy
    SyncReviewsPageJob.perform_later
    flash[:success] = "Quotation deleted."
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = "Quotation not found."
  ensure
    redirect_to comfy_admin_quotations_path
  end

  # Rebuild the Reviews page from every quotation now (also auto-enqueued on any
  # add/edit/delete).
  def sync_reviews
    SyncReviewsPageJob.perform_later
    flash[:success] = "Rebuilding the Reviews page from all quotations on the worker."
    redirect_to comfy_admin_quotations_path
  end

  private

  def load_quotations
    @quotations = comfy_paginate(Kaminari.paginate_array(SubstackQuotation.chronological.to_a), per_page: 25)
  end

end
