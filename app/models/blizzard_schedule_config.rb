# frozen_string_literal: true

# Singleton holding the popularity-weighted repost settings: interval_minutes
# (minutes between reposts), cooldown_hours (how long an entry rests after a
# repost), and last_reposted_at (the claim clock). The legacy `schedule` jsonb
# column is retired — it held the removed forecast calendar's saved arrangement.
class BlizzardScheduleConfig < ApplicationRecord
  validates :interval_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :cooldown_hours,   numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.instance
    first_or_create!
  end
end
