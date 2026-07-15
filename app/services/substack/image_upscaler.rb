# frozen_string_literal: true

require "vips"

module Substack
  # Substack won't display an image wider than its source pixels, so a banner
  # narrower than the content column shows small. Enlarge such images to the
  # column width before upload — but only up to MAX_UPSCALE, so genuinely tiny
  # images stay native and sharp rather than being blown up into mush.
  module ImageUpscaler
    FILL_WIDTH = 728    # the Substack "normal" content-column width
    MAX_UPSCALE = 2.0   # don't stretch an image by more than this

    module_function

    def fill(body, content_type)
      image = Vips::Image.new_from_buffer(body, "")
      return body if image.width >= FILL_WIDTH

      factor = FILL_WIDTH.to_f / image.width
      return body if factor > MAX_UPSCALE

      image.resize(factor).write_to_buffer(suffix(content_type))
    rescue => e
      Rails.logger.warn("[SubstackSync] image upscale skipped: #{e.message}")
      body
    end

    def suffix(content_type)
      content_type.to_s.include?("png") ? ".png" : ".jpg"
    end
  end
end
