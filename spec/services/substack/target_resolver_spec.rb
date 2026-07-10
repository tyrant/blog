# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::TargetResolver do
  subject(:resolve) { described_class.execute(url: url, client: client) }

  let(:client) { instance_double(Substack::Client) }

  context 'with a post URL' do
    let(:url) { 'https://pub.substack.com/p/some-post' }

    before do
      allow(client).to receive(:get_post).with(url).and_return(
        'publishedBylines' => [{ 'id' => 99, 'name' => 'Cory Althoff', 'handle' => 'coryalthoff' }]
      )
    end

    it 'resolves the post byline author' do
      expect(resolve).to eq('name' => 'Cory Althoff', 'handle' => 'coryalthoff', 'user_id' => 99)
    end
  end

  context 'with a note URL' do
    let(:url) { 'https://substack.com/profile/4619740-mikey-clarke/note/c-263674505' }

    before do
      allow(client).to receive(:get_note).with('263674505')
        .and_return('comment' => { 'user_id' => 4619740, 'name' => 'Mikey Clarke', 'handle' => 'mikeyclarke' })
    end

    it 'resolves the commenter' do
      expect(resolve).to eq('name' => 'Mikey Clarke', 'handle' => 'mikeyclarke', 'user_id' => 4619740)
    end
  end

  context 'with a post-comment URL' do
    let(:url) { 'https://pub.substack.com/p/some-post/comment/555' }

    before do
      allow(client).to receive(:get_note).with('555')
        .and_return('comment' => { 'user_id' => 7, 'name' => 'Reeta', 'handle' => 'reeta' })
    end

    it 'resolves via the comment id, not the post' do
      expect(client).to_not receive(:get_post)
      expect(resolve['handle']).to eq 'reeta'
    end
  end
end
