module ComfyCmsCategoryMethods
  extend ActiveSupport::Concern

  # Flag-only categories: their Categorizations carry no #url or #data,
  # just the presence of the link itself.
  BOOLEAN_LABELS = ['Shite Advice', 'Whimsy', 'NSFW'].freeze

  included do

    scope :nsfw_first, -> { where(label: 'NSFW') + nsfw_banished! }

    scope :public_names, -> { where(label: BOOLEAN_LABELS) }

    scope :nsfw_banished!, -> { where.not(label: 'NSFW') }

    scope :nsfw_banished, -> (banish) { banish ? nsfw_banished! : where('1=1') }

    def nsfw?
      label == 'NSFW'
    end

    def boolean?
      BOOLEAN_LABELS.include?(label)
    end
  end
end
