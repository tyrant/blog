# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::ImageUpscaler do
  def jpeg(width, height = 100)
    Vips::Image.black(width, height).write_to_buffer('.jpg')
  end

  def width_of(body)
    Vips::Image.new_from_buffer(body, '').width
  end

  it 'upscales a moderately narrow image to the fill width' do
    expect(width_of(described_class.fill(jpeg(454), 'image/jpeg'))).to eq 728
  end

  it 'leaves a wide-enough image untouched' do
    body = jpeg(1000)
    expect(described_class.fill(body, 'image/jpeg')).to eq body
  end

  it 'leaves a very small image native (beyond the 2x cap)' do
    body = jpeg(200) # 728/200 = 3.6x
    expect(described_class.fill(body, 'image/jpeg')).to eq body
  end

  it 'returns the original bytes on a decode error' do
    expect(described_class.fill('not an image', 'image/jpeg')).to eq 'not an image'
  end
end
