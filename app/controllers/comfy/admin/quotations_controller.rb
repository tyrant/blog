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
    # New quotations append to the end of the manual order (assign_position); the
    # rebuild mirrors that order to the Reviews pages.
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
    quotation.assign_attributes(params.permit(:post_url, :post_title, :post_image_url, :post_id))
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

  # Rebuild the Reviews pages now, mirroring the current manual order.
  def sync_reviews
    SyncReviewsPageJob.perform_later
    flash[:success] = "Rebuilding the Reviews pages from all quotations on the worker."
    redirect_to comfy_admin_quotations_path
  end

  # Persist a new manual order from the drag-to-reorder list.
  def reorder
    SubstackQuotation.reorder!(Array(params[:order]))
    head :ok
  end

  # Set the number of quotations per Substack Reviews page.
  def update_page_size
    config = SubstackSyncConfig.instance
    if config.update(reviews_page_size: params[:reviews_page_size])
      flash[:success] = "Reviews page size set to #{config.reviews_page_size}. Rebuild to apply."
    else
      flash[:danger] = "Could not set page size: #{config.errors.full_messages.to_sentence}."
    end
    redirect_to comfy_admin_quotations_path
  end

  private

  def load_quotations
    @page_size = SubstackSyncConfig.instance.reviews_page_size
    @quotations = SubstackQuotation.by_position.to_a
  end

end
