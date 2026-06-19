# frozen_string_literal: true

class SubstackSyncConfig < ApplicationRecord
  def self.instance
    first_or_create!
  end
end
