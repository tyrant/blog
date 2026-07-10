# frozen_string_literal: true

class ReplyDrafterConfig < ApplicationRecord
  SPLITS  = %w[balanced mostly_agree mostly_disagree agree disagree].freeze
  LENGTHS = %w[1 1-2 1-3 2-3].freeze

  validates :count, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 20 }
  validates :split, inclusion: { in: SPLITS }
  validates :length, inclusion: { in: LENGTHS }

  def self.instance
    first_or_create!(instructions: Substack::ReplyGenerator::DEFAULT_INSTRUCTIONS)
  end
end
