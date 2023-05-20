class NavComponent < ViewComponent::Base

  def initialize(nav_items:)
    @nav_items = nav_items
  end
end
