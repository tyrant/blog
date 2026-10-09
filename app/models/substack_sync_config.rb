# frozen_string_literal: true

class SubstackSyncConfig < ApplicationRecord
  # nil is allowed so the singleton row can be first_or_create!'d empty; a set
  # footer must be a JSON array of ProseMirror blocks.
  validate :footer_json_is_array
  validates :quotation_rotation_days, numericality: { only_integer: true, greater_than: 0 }
  validates :reviews_page_size, numericality: { only_integer: true, greater_than: 0 }

  # Tidy the subtitle variables JSON on save: sort each array's entries
  # alphabetically and pretty-print (one entry per line). Invalid JSON is left
  # untouched for the author to fix.
  before_save :normalize_subtitle_variables_json

  def self.instance
    first_or_create!
  end

  # --- Session-cookie health ---------------------------------------------------
  # The unofficial API rides one stored substack.sid cookie; when it expires every
  # sync fails. The client records health at its choke point (transition-only, so
  # no write storms) and the admin page surfaces it. note_* flip only on change;
  # record_check! always stamps (used by the manual "Check now").

  def note_session_failure!(message)
    return unless session_healthy?

    update_columns(session_healthy: false, session_error: message.to_s.first(255), session_checked_at: Time.current)
  end

  def note_session_recovery!
    return if session_healthy? && session_error.blank?

    update_columns(session_healthy: true, session_error: nil, session_checked_at: Time.current)
  end

  def record_check!(healthy:, error: nil)
    update_columns(session_healthy: healthy, session_error: error&.to_s&.first(255), session_checked_at: Time.current)
  end

  # Whether enough days have elapsed since the last rotation for the scheduled
  # (daily-firing) job to rotate again — the runtime override for what used to be
  # a hardcoded weekly cron.
  def quotation_rotation_due?
    quotations_rotated_at.nil? || quotations_rotated_at + quotation_rotation_days.days <= Time.current
  end

  # The subtitle to mirror for every post: the single subtitle template, rendered
  # with a random pick per {{ variable }} from subtitle_variables. (The post arg
  # is kept for the caller's sake — the subtitle no longer varies by post/tag.)
  def subtitle_for(_post)
    Substack::SubtitleTemplate.render(subtitle.to_s, subtitle_variables)
  end

  # The ordered Substack draft ids of the Reviews pages: page 1 is reviews_draft_id
  # (its slug/URL is preserved), pages 2..X live in reviews_extra_draft_ids and are
  # auto-created by the syncer. Empty when no page-1 id is configured.
  def reviews_page_ids
    return [] if reviews_draft_id.blank?

    [reviews_draft_id, *Array(reviews_extra_draft_ids)].compact
  end

  # Append an auto-created Reviews page id (pages 2..X). Called by the syncer when
  # the review count grows past another multiple of 20.
  def add_reviews_page_id!(id)
    update!(reviews_extra_draft_ids: Array(reviews_extra_draft_ids) + [id])
  end

  # The featurable quotations split into Reviews pages, in display order — what
  # each page renders. Always at least one (possibly empty) page.
  def reviews_page_groups
    groups = SubstackQuotation.featurable.includes(:substack_user).by_position.to_a.each_slice(reviews_page_size).to_a
    groups.empty? ? [[]] : groups
  end

  # Stamp a Reviews page (1-based) as synced with the given fingerprint. One
  # atomic jsonb_set, so concurrent page syncs never clobber each other's stamps.
  def record_reviews_page_fingerprint!(page, fingerprint)
    self.class.where(id: id).update_all([
      "reviews_page_fingerprints = jsonb_set(reviews_page_fingerprints, ARRAY[?]::text[], to_jsonb(?::text))",
      page.to_s, fingerprint
    ])
    reviews_page_fingerprints[page.to_s] = fingerprint
  end

  # Whether a Reviews page's content differs from what it was last synced with:
  # :never when it hasn't been synced since tracking began, true/false otherwise.
  def reviews_page_changed?(page, group, page_count)
    stored = reviews_page_fingerprints[page.to_s]
    return :never if stored.nil?

    stored != SubstackQuotation.reviews_page_fingerprint(group, page_count)
  end

  # Substack's editor for a draft/post — where a manual Update/Publish happens.
  def draft_editor_url(draft_id)
    "https://#{publication_host}/publish/post/#{draft_id}"
  end

  # The subtitle template variables ({ "var" => ["a", "b"] }) parsed from the JSON
  # textarea; empty hash when unset or unparseable (the author keeps it consistent).
  def subtitle_variables
    return {} if subtitle_variables_json.blank?

    parsed = JSON.parse(subtitle_variables_json)
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end

  # The footer edited as pretty JSON text in the admin form.
  def footer_json_text
    JSON.pretty_generate(footer_json || [])
  end

  def footer_json_text=(value)
    @footer_json_text_invalid = false
    self.footer_json = JSON.parse(value.to_s)
  rescue JSON::ParserError
    @footer_json_text_invalid = true
  end

  private

  def footer_json_is_array
    if @footer_json_text_invalid
      errors.add(:footer_json, "must be valid JSON")
    elsif !footer_json.nil? && !footer_json.is_a?(Array)
      errors.add(:footer_json, "must be a JSON array of blocks")
    end
  end

  def normalize_subtitle_variables_json
    return if subtitle_variables_json.blank?

    parsed = JSON.parse(subtitle_variables_json)
    return unless parsed.is_a?(Hash)

    sorted = parsed.transform_values do |value|
      value.is_a?(Array) ? value.sort_by { |entry| entry.to_s.downcase } : value
    end
    self.subtitle_variables_json = JSON.pretty_generate(sorted)
  rescue JSON::ParserError
    nil # leave invalid JSON exactly as entered
  end
end
