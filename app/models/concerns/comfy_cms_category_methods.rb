module ComfyCmsCategoryMethods
  extend ActiveSupport::Concern

  included do

    scope :nsfw_banished!, -> { where("label != 'NSFW'") }

    scope :nsfw_banished, -> (banish) { banish ? nsfw_banished! : where('1=1') }

    def nsfw?
      label == 'NSFW'
    end
  end
end
