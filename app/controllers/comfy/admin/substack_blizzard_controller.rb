# frozen_string_literal: true

class Comfy::Admin::SubstackBlizzardController < Comfy::Admin::Cms::BaseController

  DEFAULT_DAYS = 14

  # JSON API consumed by the local repost task (basic-auth is the auth).
  skip_before_action :verify_authenticity_token,
                     only: %i[add_note claim_scheduled confirm_scheduled], raise: false,
                     if: -> { request.format.json? }

  def index
    @days = clamp_days(params[:days])
    due   = Substack::Blizzard::DueFinder.execute(max_age_days: @days, title_query: params[:q])
    @due  = comfy_paginate(Kaminari.paginate_array(due), per_page: 20)
    # Every group, unfiltered — the forecast calendar spans all posts regardless
    # of the due-list filters, and recomputes occurrences entirely client-side.
    @forecast = Substack::Blizzard::ForecastData.execute
    @saved_schedule = BlizzardScheduleConfig.instance.schedule
  end

  # Persists the current forecast arrangement so it renders identically on every
  # reload and device. The payload is the compact { days, even, shuffle, events:
  # [{c, i, t}] } object the calendar builds client-side.
  def save_schedule
    payload = JSON.parse(request.raw_post)
    raise JSON::ParserError, "expected a JSON object" unless payload.is_a?(Hash)

    BlizzardScheduleConfig.instance.update!(schedule: payload.slice("days", "even", "shuffle", "events"))
    render json: { ok: true }
  rescue JSON::ParserError, ActiveRecord::RecordInvalid => e
    render json: { ok: false, error: e.message }, status: :unprocessable_content
  end

  # Phase one: claim the scheduled reposts due now (marks them claimed, hydrated
  # for the local poster). Consumed by the local `post_scheduled` task.
  def claim_scheduled
    render json: Substack::Blizzard::ScheduleClaimer.execute(limit: claim_limit)
  end

  # Read-only preview of what's due — for the local dry-run (no claiming).
  def scheduled_due
    render json: Substack::Blizzard::ScheduleClaimer.execute(limit: claim_limit, dry_run: true)
  end

  # Phase two: record a completed scheduled post (append note + mark posted).
  def confirm_scheduled
    Substack::Blizzard::ScheduleConfirmer.execute(
      categorization_id: params[:categorization_id],
      entry_index:       params[:index],
      t:                 params[:t],
      url:               params[:url],
      timestamp:         params[:timestamp]
    )
    render json: { ok: true }
  rescue => e
    render json: { ok: false, error: e.message }, status: :unprocessable_content
  end

  def create_note
    categorization = Comfy::Cms::Categorization.find(params[:categorization_id])
    record = Substack::Blizzard::Reposter.execute(
      categorization: categorization,
      entry_index:    params[:index].to_i
    )
    flash[:success] = "Posted note: #{record['url']}"
  rescue => e
    flash[:danger] = "Could not post note: #{e.message}"
  ensure
    redirect_to back_path
  end

  def add_note
    categorization = Comfy::Cms::Categorization.find(params[:categorization_id])
    entry = categorization.data.dig("blizzard", params[:index].to_i)
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
      entry_index:    params[:index].to_i,
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

  def claim_limit
    (params[:limit].presence || 5).to_i.clamp(1, 100)
  end

end
