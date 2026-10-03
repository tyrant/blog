# frozen_string_literal: true

# Singleton holding the popularity-weighted repost settings: cooldown_hours (how long
# a post rests after any of its entries reposts), last_reposted_at (an informational
# timestamp of the last recorded repost — reposting is fully manual, so nothing gates
# on it), and quotation_odds_pct/unattached_odds_pct (WeightedPicker's repost-type
# split — the remaining share goes to the per-post text-group pool). The legacy
# `schedule` jsonb column is retired — it held the removed forecast calendar's
# saved arrangement.
#
# `data` holds the unattached-Notes pool — Notes with no parent Post or
# SubstackQuotation — in the same shape as a Substack categorization's #data:
# {"notes" => [url, …], "blizzard" => [{"uid", "text", "body_json", "notes" => [{"url","timestamp","likes"}, …]}, …]}.
# "notes" is the raw list of Note URLs pasted in by hand; "Backfill" turns it into
# tracked "blizzard" entries, same as a post's notes.
class BlizzardScheduleConfig < ApplicationRecord
  validates :cooldown_hours, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :quotation_odds_pct, :unattached_odds_pct,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate  :data_is_hash
  validate  :odds_pct_leave_room_for_text_group

  def self.instance
    first_or_create!
  end

  # The remaining share after quotation + unattached — WeightedPicker's per-post
  # text-group pool. Not a column: it's whatever's left, so the three always sum
  # to 100 by construction rather than needing a three-way equality validation.
  def text_group_odds_pct
    100 - quotation_odds_pct.to_i - unattached_odds_pct.to_i
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

  def odds_pct_leave_room_for_text_group
    return if quotation_odds_pct.nil? || unattached_odds_pct.nil?

    errors.add(:base, "Quotation + unattached odds can't exceed 100%") if quotation_odds_pct + unattached_odds_pct > 100
  end
end
