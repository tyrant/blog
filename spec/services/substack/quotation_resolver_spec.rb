# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::QuotationResolver do
  let(:client) { instance_double(Substack::Client) }

  context 'a comment on a post' do
    subject(:resolved) { described_class.execute(comment_url: url, client: client) }

    let(:url) { 'https://evasolen.substack.com/p/chapter-19/comment/294035746' }

    before do
      allow(client).to receive(:get_note).with('294035746').and_return('item' => {
        'comment' => { 'name' => 'Eva Solen', 'handle' => 'evasolen', 'user_id' => 123 },
        'post' => { 'title' => 'Chapter 19', 'canonical_url' => 'https://evasolen.substack.com/p/chapter-19',
                    'cover_image' => 'https://substackcdn.com/image/fetch/cover.jpg', 'id' => 42 }
      })
    end

    it { expect(resolved.post_url).to eq 'https://evasolen.substack.com/p/chapter-19' }
    it { expect(resolved.post_title).to eq 'Chapter 19' }
    it { expect(resolved.post_image_url).to eq 'https://substackcdn.com/image/fetch/cover.jpg' }
    it { expect(resolved.post_id).to eq 42 }
    it { expect(resolved.author_name).to eq 'Eva Solen' }
    it { expect(resolved.author_handle).to eq 'evasolen' }
    it { expect(resolved.author_user_id).to eq 123 }
  end

  context 'a commenter with no handle' do
    subject(:resolved) { described_class.execute(comment_url: 'https://x/comment/5', client: client) }

    before do
      allow(client).to receive(:get_note).with('5').and_return('item' => {
        'comment' => { 'name' => 'Anon' }, 'post' => {}
      })
    end

    it { expect(resolved.author_handle).to be_nil }
  end

  context 'a Substack page URL with no comment or note' do
    subject(:resolved) { described_class.execute(comment_url: url, client: client) }

    let(:url) { 'https://greblksnew.substack.com/recommendations' }

    before { allow(client).to receive(:get_note) }

    it 'stands in for the publication without a lookup' do
      expect(resolved.post_url).to eq Substack::PostMetadata::GENERIC_POST_URL
      expect(resolved.post_title).to eq Substack::PostMetadata::GENERIC_POST_TITLE
      expect(resolved.post_image_url).to eq Substack::PostMetadata::FALLBACK_IMAGE_URL
      expect(client).to_not have_received(:get_note)
    end

    it { expect(resolved.author_name).to be_nil }

    context 'the publication base URL' do
      let(:url) { 'https://mikeyclarke.substack.com' }

      it { expect(resolved.post_url).to eq Substack::PostMetadata::GENERIC_POST_URL }
    end
  end

  context 'a URL that is not a comment, note or Substack page' do
    %w[https://example.com/whatever http://greblksnew.substack.com/recommendations
       https://notsubstack.com/recommendations not-a-url].each do |url|
      it "rejects #{url}" do
        expect { described_class.execute(comment_url: url, client: client) }
          .to raise_error(ArgumentError, /comment, note or page/)
      end
    end
  end
end
