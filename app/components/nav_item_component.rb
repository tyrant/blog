class NavItemComponent < ViewComponent::Base

  VIEWPORTS = %w(desktop mobile)

  def initialize(nav_item:, for_viewport:)
    raise 'Valid viewport please' unless VIEWPORTS.include?(for_viewport)

    @nav_item = nav_item
    @for_viewport = for_viewport
  end

  private

  def html_attrs
    attrs = { class: css_classes }
    attrs[:aria] = aria_attrs if aria_attrs

    attrs
  end

  def aria_attrs
    if current_page? @nav_item[:path]
      { current: 'page' }
    else
      nil
    end
  end

  def css_classes
    if current_page? @nav_item[:path]
      classes_for_current_page
    else
      classes_for_not_current_page
    end + send("classes_for_#{@for_viewport}")
  end

  def classes_for_desktop
    %w(px-3 py-2 rounded-md text-sm font-medium)
  end

  def classes_for_mobile
    %w(block px-3 py-2 rounded-md text-sm font-medium)
  end

  def classes_for_current_page
    %w(bg-gray-900 text-white)
  end

  def classes_for_not_current_page
    %w(text-gray-300 hover:bg-gray-700 hover:text-white)
  end  
end
