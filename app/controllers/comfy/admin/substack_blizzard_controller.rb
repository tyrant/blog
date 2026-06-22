# frozen_string_literal: true

class Comfy::Admin::SubstackBlizzardController < Comfy::Admin::Cms::BaseController

  DEFAULT_DAYS = 14

  def index
    @days = clamp_days(params[:days])
    due   = Substack::Blizzard::DueFinder.execute(max_age_days: @days)
    @due  = comfy_paginate(Kaminari.paginate_array(due), per_page: 20)
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

    if entry && params[:url].present? && timestamp.present?
      entry["notes"] << { "url" => params[:url], "timestamp" => timestamp }
      categorization.update!(data: categorization.data)
      flash[:success] = "Recorded note for that text group."
    else
      flash[:danger] = "A note URL and a readable timestamp (e.g. “21 Jun at 19:00”) are both required."
    end

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
