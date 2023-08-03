# frozen_string_literal: true

# Displays a nifty and/or temporary notification to the user.
# A lovely little UI widget thing appears on-screen, showing a small amount of
# HTML, then fades out and vanishes.
#
# Params:
#  - `type` One of TYPES. The choice governs the HTML's styling and icon choices.
#  - `html_content` The content displayed. Keeping the HTML valid and looking
#      fab is the responsibility of the caller, i.e. me.
#  - `showtime` The duration, in milliseconds, that this widget is displayed
#      before it gets faded-out and deleted by its Stimulus controller code.
class NotificationComponent < ViewComponent::Base

  TYPES = %w(success error info)

  def initialize(type:, html_content:, showtime: 3000)
    raise '' unless TYPES.include? type
    @type = type
    @html_content = html_content
    @showtime = showtime
  end

  private

  # Reminder: all ViewComponent methods spitting out CSS classes return arrays
  # of css class names, rather than a space-separated single string list of
  # them. Makes it easier for class-generation methods to call other methods.
  # It's up to the view code to call .join(' ') on the result.

  def panel_css_classes
    common_css_classes + per_type_css_classes
  end

  def common_css_classes
    %w(p-3 w-full flex rounded-lg shadow-lg hover:shadow-xl transition-opacity duration-1000 text-sm)
  end

  def per_type_css_classes
    {
      'success' => %w(bg-green-100 text-green-600),
      'error'   => %w(bg-red-100 text-red-600),
      'info'    => %w(bg-blue-100 text-blue-600)
    }[@type]
  end

end
