# frozen_string_literal: true

module Comfy::Cms::WithCategories

  extend ActiveSupport::Concern

  included do
    has_many :categorizations,
      as:         :categorized,
      class_name: "Comfy::Cms::Categorization",
      dependent:  :destroy
    has_many :categories,
      through:    :categorizations,
      class_name: "Comfy::Cms::Category"

    attr_writer :category_ids
    attr_reader :categorizations_data

    validate :categorizations_data_is_valid_json

    after_save :sync_categories
    after_save :sync_categorizations_data

    scope :for_category, ->(*categories) {
      if (categories = [categories].flatten.compact).present?
        distinct
          .joins(categorizations: :category)
          .where("comfy_cms_categories.label" => categories)
      end
    }
  end

  def category_ids
    @category_ids ||= categories.pluck(:id)
  end

  # Hash keyed by category id, e.g. { "5" => { "url" => "...", "data" => "{...}" } }.
  # #data arrives as a raw JSON string from the admin textarea.
  def categorizations_data=(hash)
    @categorizations_data = hash
  end

  def sync_categories
    return unless category_ids.is_a?(Array)

    scope = Comfy::Cms::Category.of_type(self.class.to_s)
    existing_ids = scope.pluck(:id)

    ids_to_add = category_ids.map(&:to_i)

    # adding categorizations
    ids_to_add.each do |id|
      if (category = scope.find_by_id(id))
        category.categorizations.create(categorized: self)
      end
    end

    # removing categorizations
    ids_to_remove = existing_ids - ids_to_add
    categorizations.where(category_id: ids_to_remove).destroy_all
  end

  # Runs after sync_categories, so newly-ticked categorizations already exist.
  def sync_categorizations_data
    return if categorizations_data.blank?

    categorizations_data.each do |category_id, attrs|
      categorization = categorizations.find_by(category_id: category_id)
      next unless categorization

      categorization.update!(
        url:  attrs[:url].presence || attrs["url"].presence,
        data: parse_categorization_data(attrs[:data] || attrs["data"])
      )
    end
  end

protected

  def parse_categorization_data(raw)
    return {} if raw.blank?
    JSON.parse(raw)
  end

  def categorizations_data_is_valid_json
    return if categorizations_data.blank?

    categorizations_data.each do |category_id, attrs|
      raw = attrs[:data] || attrs["data"]
      next if raw.blank?
      JSON.parse(raw)
    rescue JSON::ParserError
      label = Comfy::Cms::Category.find_by(id: category_id)&.label || category_id
      errors.add(:base, "Invalid JSON in #{label} data")
    end
  end

end
