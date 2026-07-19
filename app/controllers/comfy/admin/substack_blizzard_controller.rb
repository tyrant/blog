# frozen_string_literal: true

class Comfy::Admin::SubstackBlizzardController < Comfy::Admin::Cms::BaseController

  DEFAULT_DAYS = 14

  # JSON API consumed by the local repost task (basic-auth is the auth).
  skip_before_action :verify_authenticity_token,
                     only: %i[add_note repost_tick repost_confirm], raise: false,
                     if: -> { request.format.json? }

  def index
    @days = clamp_days(params[:days])
    due   = Substack::Blizzard::DueFinder.execute(max_age_days: @days, title_query: params[:q])
    @due  = comfy_paginate(Kaminari.paginate_array(due), per_page: 20)
    @config = BlizzardScheduleConfig.instance
    @odds = Substack::Blizzard::RepostOdds.execute.max_by(10, &:weight)
    @blizzard_stats = BlizzardStatSnapshot.current_totals
    @stat_series = stat_series
  end

  # Enqueues a backfill of every Substack post's notes (runs on the prod worker).
  def backfill_all
    BackfillAllJob.perform_later
    flash[:success] = "Backfill started for all posts — reposts will update shortly."
    redirect_to back_path
  end

  # Live progress of the background jobs, polled by the admin's Background jobs
  # panel. Finished jobs are omitted so their bar disappears on completion; failed
  # ones stay so a failure is noticed.
  def job_progress
    render json: JobProgress.where.not(status: "finished").order(:label).map { |p|
      { key: p.key, label: p.label, total: p.total, completed: p.completed,
        percent: p.percent, status: p.status, updated_at: p.updated_at.iso8601 }
    }
  end

  # Enqueues a likes refresh for every Substack note (runs on the prod worker).
  def refresh_likes
    RefreshNotePostLikesJob.perform_later
    flash[:success] = "Likes refresh started — note like-counts will update shortly."
    redirect_to back_path
  end

  # Enqueues a backfill of one post's notes (from the CMS post editor).
  def backfill_post
    post = Comfy::Blog::Post.find_by(id: params[:post_id])
    categorization = post && Comfy::Cms::Categorization
      .joins(:category)
      .find_by(categorized: post, comfy_cms_categories: { label: "Substack" })
    if categorization
      BackfillPostJob.perform_later(categorization.id)
      flash[:success] = "Backfill started for this post’s notes."
    else
      flash[:danger] = "No Substack notes found for this post."
    end
    redirect_back fallback_location: comfy_admin_substack_blizzard_path
  end

  # Phase one: the local ticker asks for the next weighted repost. Returns one
  # hydrated entry (claiming it), or {} when it's not yet time / nothing eligible.
  def repost_tick
    render json: Substack::Blizzard::WeightedPicker.execute || {}
  end

  # Read-only preview of what would be picked next — for the local dry-run.
  def repost_preview
    render json: Substack::Blizzard::WeightedPicker.execute(dry_run: true) || {}
  end

  # A random (or ?id=) quotation note, built exactly as the ticker would fire it,
  # for the local preview task to post-and-inspect. Nothing is claimed.
  def quotation_preview
    quotation = params[:id].present? ? SubstackQuotation.find(params[:id]) :
      SubstackQuotation.order(Arel.sql("RANDOM()")).first
    render json: (quotation && {
      "text"      => quotation.quotation,
      "post_url"  => quotation.post_url,
      "body_json" => Substack::Blizzard::QuotationNote.build(quotation)
    }) || {}
  end

  # Phase two: record a completed repost (append note to the entry, by uid).
  def repost_confirm
    Substack::Blizzard::RepostRecorder.execute(
      categorization_id: params[:categorization_id],
      uid:               params[:uid],
      url:               params[:url],
      timestamp:         params[:timestamp]
    )
    render json: { ok: true }
  rescue => e
    render json: { ok: false, error: e.message }, status: :unprocessable_content
  end

  # Admin: update the repost cadence (minutes between reposts) and per-post cooldown.
  def update_settings
    BlizzardScheduleConfig.instance.update!(
      interval_minutes: params[:interval_minutes],
      cooldown_hours:   params[:cooldown_hours]
    )
    flash[:success] = "Repost settings updated."
  rescue ActiveRecord::RecordInvalid => e
    flash[:danger] = "Could not update settings: #{e.message}"
  ensure
    redirect_to back_path
  end

  def create_note
    categorization = Comfy::Cms::Categorization.find(params[:categorization_id])
    record = Substack::Blizzard::Reposter.execute(
      categorization: categorization,
      uid:            params[:uid]
    )
    flash[:success] = "Posted note: #{record['url']}"
  rescue => e
    flash[:danger] = "Could not post note: #{e.message}"
  ensure
    redirect_to back_path
  end

  def add_note
    categorization = Comfy::Cms::Categorization.find(params[:categorization_id])
    entry = Array(categorization.data["blizzard"]).find { |e| e["uid"] == params[:uid] }
    timestamp = Substack::NoteParser.parse_human_timestamp(params[:timestamp])
    ok = entry && params[:url].present? && timestamp.present?

    if ok
      entry["notes"] << { "url" => params[:url], "timestamp" => timestamp }
      categorization.update!(data: categorization.data)
    end

    respond_to do |format|
      format.html do
        flash[ok ? :success : :danger] = ok ? "Recorded note for that text group." :
          "A note URL and a readable timestamp (e.g. “21 Jun at 19:00”) are both required."
        redirect_to back_path
      end
      format.json { render json: { success: ok }, status: (ok ? :ok : :unprocessable_entity) }
    end
  end

  # Re-seed an entry's body_json from a real (rich) Note — a server-side read,
  # which is allowed from the prod IP.
  def reseed
    categorization = Comfy::Cms::Categorization.find(params[:categorization_id])
    entry = Substack::Blizzard::Reseeder.execute(
      categorization: categorization,
      uid:            params[:uid],
      note_url:       params[:note_url]
    )
    flash[:success] = "Re-seeded rich text from that note (#{entry['text'].to_s.length} chars)."
  rescue => e
    flash[:danger] = "Could not re-seed: #{e.message}"
  ensure
    redirect_to back_path
  end

  private

  def back_path
    comfy_admin_substack_blizzard_path(days: clamp_days(params[:days]), page: params[:page].presence, q: params[:q].presence)
  end

  def clamp_days(value)
    (value.presence || DEFAULT_DAYS).to_i.clamp(0, 60)
  end

  # The recorded totals as parallel arrays for the Chart.js "Totals over time" graph.
  def stat_series
    snapshots = BlizzardStatSnapshot.chronological
    {
      labels:  snapshots.map { |s| s.captured_at.in_time_zone("Pacific/Auckland").strftime("%-d %b %H:%M") },
      posts:   snapshots.map(&:posts),
      entries: snapshots.map(&:entries),
      notes:   snapshots.map(&:notes)
    }
  end

end
