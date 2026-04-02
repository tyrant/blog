# frozen_string_literal: true

class MediumSyncConfig < ApplicationRecord
  validates :title_template, :content_template, :link_template, presence: true

  def self.instance
    first_or_create!(
      title_template:   "{{title}}",
      subtitle:         "",
      content_template: "{{content}}",
      link_template:    "original: {{url}}",
      footer_html:      ""
    )
  end
end
