# frozen_string_literal: true

class Comfy::Admin::SubstackBlizzardController < Comfy::Admin::Cms::BaseController

  DEFAULT_DAYS = 14

  # JSON API consumed by the local repost task (basic-auth is the auth).
  skip_before_action :verify_authenticity_token, only: :add_note, raise: false,
                     if: -> { request.format.json? }

  def index
    @days = clamp_days(params[:days])
    due   = Substack::Blizzard::DueFinder.execute(max_age_days: @days)
    @due  = comfy_paginate(Kaminari.paginate_array(due), per_page: 20)
  end

  # Due groups (with body_json) for the local repost task to post from.
  def due
    groups = Substack::Blizzard::DueFinder.execute(max_age_days: clamp_days(params[:days])).map do |d|
      {
        categorization_id: d.categorization.id,
        index:             d.index,
        text:              d.entry["text"],
        body_json:         d.entry["body_json"],
        post_url:          d.categorization.url,
        template_url:      Array(d.entry["notes"]).map { |n| n["url"] }.compact.first
      }
    end
    render json: groups
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
    comfy_admin_substack_blizzard_path(days: clamp_days(params[:days]), page: params[:page].presence)
  end

  def clamp_days(value)
    (value.presence || DEFAULT_DAYS).to_i.clamp(1, 60)
  end

end
