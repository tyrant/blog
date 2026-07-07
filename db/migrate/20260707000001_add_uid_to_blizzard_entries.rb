# frozen_string_literal: true

# Gives every blizzard text-group a stable uid so schedules, reposts and
# confirmations key off it rather than the fragile array index. Also rewrites the
# saved schedule's event refs from { c, i, t } to { c, u, t }.
class AddUidToBlizzardEntries < ActiveRecord::Migration[8.0]
  def up
    index_to_uid = {} # [categorization_id, array_index] => uid

    Comfy::Cms::Categorization.find_each do |cat|
      entries = cat.data["blizzard"]
      next unless entries.is_a?(Array) && entries.any?

      entries.each_with_index do |entry, i|
        entry["uid"] ||= SecureRandom.uuid
        index_to_uid[[cat.id, i]] = entry["uid"]
      end
      cat.update_column(:data, cat.data)
    end

    translate_schedule(index_to_uid)
  end

  def down
    Comfy::Cms::Categorization.find_each do |cat|
      entries = cat.data["blizzard"]
      next unless entries.is_a?(Array) && entries.any?

      entries.each { |entry| entry.delete("uid") }
      cat.update_column(:data, cat.data)
    end
  end

  private

  def translate_schedule(index_to_uid)
    config = BlizzardScheduleConfig.first
    events = Array(config&.schedule&.dig("events"))
    return if events.empty?

    events.each do |event|
      next unless event.key?("i")

      uid = index_to_uid[[event["c"], event["i"]]]
      event["u"] = uid if uid
      event.delete("i")
    end
    config.update_column(:schedule, config.schedule)
  end
end
