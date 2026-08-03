# frozen_string_literal: true

# Embeds the Mission Control jobs dashboard (SolidQueue, mounted at /admin/jobs)
# in an iframe so it keeps ComfyAdmin's chrome and nav rather than replacing the
# whole page with Mission Control's own layout.
class Comfy::Admin::SolidQueueController < Comfy::Admin::Cms::BaseController
  def show
  end
end
