# frozen_string_literal: true

class BlueskySyncConfig < ApplicationRecord
  # Credentials are validated on update only so the singleton row can be
  # first_or_create!'d empty, then filled in via the admin form.
  validates :handle, :app_password, presence: true, on: :update

  def self.instance
    first_or_create!
  end

  # The teaser lead line prepended before a post's title + link — a "Shite
  # Advice" variant for those posts when one is set, the default otherwise.
  def lead_for(post)
    if post.tags.exists?(name: "Shite Advice") && lead_shite.present?
      lead_shite
    else
      lead.to_s
    end
  end
end
