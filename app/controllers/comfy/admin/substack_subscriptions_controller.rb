# frozen_string_literal: true

# Lists the owner's Substack subscriptions for pruning. Each free one has an
# Unsubscribe button (Turbo Stream: the row is removed in place); paid ones are
# cancelled by hand in Substack.
class Comfy::Admin::SubstackSubscriptionsController < Comfy::Admin::Cms::BaseController

  CHECK_PROGRESS_KEY = "check_substack_subscriptions"

  def index
    @filter = SubstackSubscription::FILTERS.key?(params[:show]) ? params[:show] : "candidates"
    scope = SubstackSubscription.filtered(@filter).search(params[:q]).with_interaction_counts
    @subscriptions = comfy_paginate(scope.sorted_by(params[:order], params[:direction]), per_page: 50)
    @counts = {
      total:      SubstackSubscription.count,
      checked:    SubstackSubscription.where.not(checked_at: nil).count,
      candidates: SubstackSubscription.candidates.count,
      errors:     SubstackSubscription.errored.count
    }
    @progress = JobProgress.find_by(key: CHECK_PROGRESS_KEY, status: "running")
  end

  def import
    return redirect_busy if checking?

    ImportSubstackSubscriptionsJob.perform_later
    flash[:success] = "Importing your subscriptions — new ones are then checked in the background."
    redirect_to action: :index
  end

  def recheck
    return redirect_busy if checking?

    CheckSubstackSubscriptionsJob.perform_later(recheck: true)
    flash[:success] = "Re-checking every subscription in the background (about a second each)."
    redirect_to action: :index
  end

  def unsubscribe
    subscription = SubstackSubscription.find(params[:id])
    Substack::Unsubscriber.execute(subscription)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(subscription) }
      format.html do
        flash[:success] = "Unsubscribed from #{subscription.publication_name}."
        redirect_back fallback_location: comfy_admin_substack_subscriptions_path
      end
    end
  rescue Substack::Unsubscriber::Error, Substack::Client::Error => e
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(helpers.dom_id(subscription, :unsubscribe),
                                                 helpers.tag.span("failed", class: "text-danger small", title: e.message))
      end
      format.html do
        flash[:danger] = "Couldn’t unsubscribe from #{subscription.publication_name}: #{e.message}"
        redirect_back fallback_location: comfy_admin_substack_subscriptions_path
      end
    end
  end

  protected

  # A running check that has advanced recently; a stale one (a killed worker) doesn't block.
  def checking?
    JobProgress.where(key: CHECK_PROGRESS_KEY, status: "running").where("updated_at > ?", 5.minutes.ago).exists?
  end

  def redirect_busy
    flash[:danger] = "A check is already running — wait for it to finish."
    redirect_to action: :index
  end

end
