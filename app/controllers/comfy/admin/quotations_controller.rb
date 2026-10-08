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
    quotation.previewable = params[:previewable].present?
    if comment_changed
      # A new comment re-resolves post and author from the comment itself.
      quotation.populate_from_substack!
    elsif params.key?(:post_url)
      # Title and thumbnail are never typed — they come from the post the URL names.
      quotation.post_url = params[:post_url]
      quotation.post_url.present? ? quotation.populate_post_from_substack! : quotation.clear_post_metadata
    end
    quotation.save!
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
    flash[:success] = "Quotation deleted."
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = "Quotation not found."
  ensure
    redirect_to comfy_admin_quotations_path
  end

  # Rebuild one Reviews page now, mirroring the current manual order.
  def sync_reviews
    page = params[:page].to_i
    if page.positive?
      SyncReviewsPageJob.perform_later(page)
      flash[:success] = "Syncing Reviews page #{page} on the worker."
    else
      flash[:danger] = "No Reviews page given."
    end
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
      flash[:success] = "Reviews page size set to #{config.reviews_page_size}. Sync every page to apply."
    else
      flash[:danger] = "Could not set page size: #{config.errors.full_messages.to_sentence}."
    end
    redirect_to comfy_admin_quotations_path
  end

  private

  def load_quotations
    @page_size = SubstackSyncConfig.instance.reviews_page_size
    @quotations = SubstackQuotation.by_position.to_a
    load_reviews_pages
  end

  # One row per Reviews page for the per-page Sync buttons: its draft (absent
  # until the syncer auto-creates it), whether its quotations changed since it
  # was last synced, and whether its last publish is waiting on a manual Update.
  def load_reviews_pages
    config     = SubstackSyncConfig.instance
    groups     = config.reviews_page_groups
    draft_ids  = config.reviews_page_ids
    pending    = SubstackPendingPublish.where(draft_id: draft_ids.compact).pluck(:draft_id).to_set

    @reviews_pages = groups.each_with_index.map do |group, i|
      draft_id = draft_ids[i]
      {
        number:    i + 1,
        size:      group.size,
        draft_url: draft_id && config.draft_editor_url(draft_id),
        changed:   config.reviews_page_changed?(i + 1, group, groups.size),
        pending:   pending.include?(draft_id.to_i)
      }
    end
  end

end
