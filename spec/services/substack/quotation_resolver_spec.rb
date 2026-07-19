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
                    'cover_image' => 'https://substackcdn.com/image/fetch/cover.jpg' }
      })
    end

    it { expect(resolved.post_url).to eq 'https://evasolen.substack.com/p/chapter-19' }
    it { expect(resolved.post_title).to eq 'Chapter 19' }
    it { expect(resolved.post_image_url).to eq 'https://substackcdn.com/image/fetch/cover.jpg' }
    it { expect(resolved.author_name).to eq 'Eva Solen' }
    it { expect(resolved.author_url).to eq 'https://substack.com/@evasolen' }
  end

  context 'a commenter with no handle' do
    subject(:resolved) { described_class.execute(comment_url: 'https://x/comment/5', client: client) }

    before do
      allow(client).to receive(:get_note).with('5').and_return('item' => {
        'comment' => { 'name' => 'Anon' }, 'post' => {}
      })
    end

    it { expect(resolved.author_url).to be_nil }
  end

  context 'a URL that is not a comment or note' do
    it do
      expect { described_class.execute(comment_url: 'https://example.com/whatever', client: client) }
        .to raise_error(ArgumentError, /comment or note/)
    end
  end
end
