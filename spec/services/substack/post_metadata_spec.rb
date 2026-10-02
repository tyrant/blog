# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::PostMetadata do
  subject(:resolved) { described_class.execute(post_url: url, client: client) }

  let(:client) { instance_double(Substack::Client) }
  let(:url) { 'https://evasolen.substack.com/p/chapter-19' }

  context 'a post with a cover image' do
    before do
      allow(client).to receive(:get_post).with(url).and_return(
        'title' => 'Chapter 19', 'cover_image' => 'https://substackcdn.com/image/fetch/cover.jpg', 'id' => 42
      )
    end

    it { expect(resolved.post_title).to eq 'Chapter 19' }
    it { expect(resolved.post_image_url).to eq 'https://substackcdn.com/image/fetch/cover.jpg' }
    it { expect(resolved.post_id).to eq 42 }
  end

  context 'a post with no cover image' do
    before { allow(client).to receive(:get_post).with(url).and_return('title' => 'Bare', 'id' => 7) }

    it { expect(resolved.post_image_url).to eq described_class::FALLBACK_IMAGE_URL }
    it { expect(resolved.post_title).to eq 'Bare' }
  end

  context 'a post whose cover image is blank' do
    before { allow(client).to receive(:get_post).with(url).and_return('title' => 'Bare', 'cover_image' => '') }

    it { expect(resolved.post_image_url).to eq described_class::FALLBACK_IMAGE_URL }
  end

  context 'a URL that is not a Substack post' do
    let(:url) { 'https://example.com/whatever' }

    before { allow(client).to receive(:get_post).and_raise(Substack::Client::Error, 'Not a Substack post URL') }

    it { expect { resolved }.to raise_error(Substack::Client::Error, /Not a Substack post URL/) }
  end
end
