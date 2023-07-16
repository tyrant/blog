module ComfyCmsCategoryMethods
  extend ActiveSupport::Concern

  included do

    scope :nsfw_first, -> { where(label: 'NSFW') + nsfw_banished! }

    scope :public_names, -> { where(label: ['Shite Advice', 'Whimsy', 'NSFW']) }

    scope :nsfw_banished!, -> { where.not(label: 'NSFW') }

    scope :nsfw_banished, -> (banish) { banish ? nsfw_banished! : where('1=1') }

    def nsfw?
      label == 'NSFW'
    end
  end
end
