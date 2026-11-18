# frozen_string_literal: true

# Substack Favourites: the accounts whose posts and Notes I want to keep up with
# and reply to. Shows their recent content as a feed of links (refreshed in the
# background), the favourites themselves, and suggested favourites ranked by how
# much they've engaged with my own posts and Notes (SubstackEngagement).
class Comfy::Admin::SubstackFavouritesController < Comfy::Admin::Cms::BaseController

  FEED_PER_PAGE = 30
  FAVOURITES_PER_PAGE = 20
  SUGGESTIONS = 50

  def index
    @kind = SubstackFavouriteItem::KINDS.include?(params[:kind]) ? params[:kind] : nil
    items = SubstackFavouriteItem.pending.from_favourites
    items = items.where(kind: @kind) if @kind
    @items = items.newest_first.includes(:substack_user).page(params[:feed_page]).per(FEED_PER_PAGE)
    @replied_ids = SubstackFavouriteItem.replied_ids(@items)
    @favourites = SubstackUser.favourites.alphabetical.page(params[:page]).per(FAVOURITES_PER_PAGE)
    @favourite_stats = SubstackEngagement.leaderboard.where(user_id: @favourites.filter_map(&:user_id)).index_by(&:user_id)
    @suggestion_order = SubstackEngagement::SORT_COLUMNS.key?(params[:order]) ? params[:order] : "score"
    @suggestions = SubstackEngagement.suggestions(order: @suggestion_order, exclude_user_ids: [SubstackSyncConfig.instance.author_id])
                                     .limit(SUGGESTIONS)
    @refreshing = running(RefreshSubstackFavouritesJob::PROGRESS_KEY)
    @scanning = running(ScanSubstackEngagementJob::PROGRESS_KEY)
    @last_refresh = finished(RefreshSubstackFavouritesJob::PROGRESS_KEY)
    @last_scan = finished(ScanSubstackEngagementJob::PROGRESS_KEY)
  end

  # Adds a favourite from the form (a handle, @handle or profile URL) or from a
  # suggestion's Add button (user_id, handle, name).
  def create
    user = params[:user_id].present? ? from_suggestion : from_form
    user.update!(favourite: true)
    flash[:success] = "Added #{label(user)} to favourites — Refresh to pull in their posts and Notes."
    redirect_to action: :index
  rescue ArgumentError, ActiveRecord::RecordInvalid, Substack::Client::Error => e
    flash[:danger] = "Couldn’t add that favourite: #{e.message}"
    redirect_to action: :index
  end

  def remove
    user = SubstackUser.find(params[:id])
    user.update!(favourite: false)
    flash[:success] = "Removed #{label(user)} from favourites."
    redirect_back fallback_location: comfy_admin_substack_favourites_path
  end

  def refresh
    return redirect_busy("The feed is already refreshing.") if running(RefreshSubstackFavouritesJob::PROGRESS_KEY)

    RefreshSubstackFavouritesJob.perform_later
    flash[:success] = "Refreshing the feed in the background — reload in a minute."
    redirect_to action: :index
  end

  def scan
    return redirect_busy("An engagement scan is already running.") if running(ScanSubstackEngagementJob::PROGRESS_KEY)

    full = params[:full].present?
    ScanSubstackEngagementJob.perform_later(full: full)
    flash[:success] = "#{full ? 'Full' : 'Incremental'} engagement scan started in the background — it can take a while."
    redirect_to action: :index
  end

  def dismiss
    item = SubstackFavouriteItem.find(params[:id])
    item.update!(dismissed_at: Time.current)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(item) }
      format.html { redirect_back fallback_location: comfy_admin_substack_favourites_path }
    end
  end

  protected

  # Likers come without a handle; fetch it so the favourite links to their profile.
  def from_suggestion
    handle = params[:handle].presence || begin
      Substack::Client.new.handle_for(params[:user_id])
    rescue StandardError
      nil
    end
    SubstackUser.identify(user_id: params[:user_id], handle: handle, name: params[:name]) or raise ArgumentError, "no account given"
  end

  # Looks the handle up on Substack for its id and name; adds by handle alone if that fails.
  def from_form
    handle = self.class.handle_from(params[:favourite]) or raise ArgumentError, "enter a Substack handle or profile URL"
    profile = begin
      Substack::Client.new.public_profile_by_handle(handle)
    rescue Substack::Client::NotFound
      raise ArgumentError, "no Substack account @#{handle}"
    rescue Substack::Client::Error
      {}
    end
    SubstackUser.identify(user_id: profile["id"], handle: profile["handle"].presence || handle, name: profile["name"])
  end

  # "@name", "name", "https://substack.com/@name", "https://substack.com/@name/note/c-1"
  # or "https://substack.com/profile/123-name" → "name".
  def self.handle_from(input)
    text = input.to_s.strip
    handle = text[%r{substack\.com/@([\w.-]+)}, 1] || text[%r{substack\.com/profile/\d+-([\w.-]+)}, 1] ||
             (text.delete_prefix("@") if text.delete_prefix("@").match?(/\A[\w.-]+\z/))
    handle.presence
  end

  def label(user)
    user.handle ? "@#{user.handle}" : user.name.to_s
  end

  def running(key)
    JobProgress.find_by(key: key, status: "running")
  end

  def finished(key)
    JobProgress.find_by(key: key, status: "finished")
  end

  def redirect_busy(message)
    flash[:warning] = message
    redirect_to action: :index
  end

end
