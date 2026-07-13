module ComfyCmsCategoryMethods
  extend ActiveSupport::Concern

  # Flag-only categories: their Categorizations carry no #url or #data, just the
  # presence of the link itself. The topical trio (Whimsy/NSFW/Shite Advice) has
  # moved to Tags, so no live category is flag-only anymore; boolean? stays as
  # the rule for whether the admin form shows #url/#data fields.
  BOOLEAN_LABELS = ['Shite Advice', 'Whimsy', 'NSFW'].freeze

  included do

    def boolean?
      BOOLEAN_LABELS.include?(label)
    end
  end
end
