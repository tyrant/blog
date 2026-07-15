# frozen_string_literal: true

class SubstackSyncConfig < ApplicationRecord
  # nil is allowed so the singleton row can be first_or_create!'d empty; a set
  # footer must be a JSON array of ProseMirror blocks.
  validate :footer_json_is_array

  def self.instance
    first_or_create!
  end

  # The subtitle to mirror for a post: the "Shite Advice" one for terrible-advice
  # posts, the default one otherwise.
  def subtitle_for(post)
    post.tags.exists?(name: "Shite Advice") ? subtitle.to_s : subtitle_default.to_s
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
end
