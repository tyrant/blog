class ModalComponent < ViewComponent::Base

  # @type usage: the modal's DOM ID is "modal_#{type}"; and if type=='irritate',
  # then clicking outside the modal doesn't close it. That's all.
  def initialize(type:)
    @type = type
  end
end
