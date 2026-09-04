# frozen_string_literal: true

# Singleton holding the popularity-weighted repost settings: interval_minutes
# (minutes between reposts), cooldown_hours (how long a post rests after any of its
# entries reposts), and last_reposted_at (the claim clock). The legacy `schedule` jsonb
# column is retired — it held the removed forecast calendar's saved arrangement.
#
# `data` holds the unattached-Notes pool — Notes with no parent Post or
# SubstackQuotation — in the same shape as a Substack categorization's #data:
# {"notes" => [url, …], "blizzard" => [{"uid", "text", "body_json", "notes" => [{"url","timestamp","likes"}, …]}, …]}.
# "notes" is the raw list of Note URLs pasted in by hand; "Backfill" turns it into
# tracked "blizzard" entries, same as a post's notes.
class BlizzardScheduleConfig < ApplicationRecord
  validates :interval_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :cooldown_hours,   numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate  :data_is_hash

  def self.instance
    first_or_create!
  end

  # The unattached-notes data edited as pretty JSON text in the admin form.
  def data_json_text
    JSON.pretty_generate(data.presence || { "notes" => [] })
  end

  def data_json_text=(value)
    @data_json_text_invalid = false
    self.data = JSON.parse(value.to_s)
  rescue JSON::ParserError
    @data_json_text_invalid = true
  end

  private

  def data_is_hash
    if @data_json_text_invalid
      errors.add(:data, "must be valid JSON")
    elsif !data.nil? && !data.is_a?(Hash)
      errors.add(:data, "must be a JSON object")
    end
  end
end
