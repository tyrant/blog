# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::ReplyResolver do
  subject(:resolve) { described_class.execute(reply_url: url, client: client) }

  let(:client) { instance_double(Substack::Client) }

  context 'a reply to a post (empty ancestor_path)' do
    let(:url) { 'https://pub.substack.com/p/some-post/comment/292089644' }

    before do
      allow(client).to receive(:get_note).with('292089644').and_return('item' => {
        'comment' => { 'id' => 292089644, 'ancestor_path' => '', 'date' => '2026-07-10T20:12:13.750Z' },
        'post' => { 'canonical_url' => 'https://pub.substack.com/p/some-post',
                    'publishedBylines' => [{ 'name' => 'Ryn', 'handle' => 'rynboelter', 'id' => 515131244 }] }
      })
    end

    it { expect(resolve.target_url).to eq 'https://pub.substack.com/p/some-post' }
    it { expect(resolve.author_handle).to eq 'rynboelter' }
    it { expect(resolve.author_user_id).to eq 515131244 }
    it { expect(resolve.replied_at).to eq '2026-07-10T20:12:13.750Z' }
  end

  context 'a reply deep in a Note thread rooted at a shared post' do
    let(:url) { 'https://substack.com/profile/4619740-mikey-clarke/note/c-292303478' }

    before do
      allow(client).to receive(:get_note).with('292303478').and_return('item' => {
        'comment' => { 'ancestor_path' => '292016360.292299371', 'date' => 't' },
        'post' => { 'canonical_url' => 'https://thearchivedstories.substack.com/p/perfectionism' },
        'parentComments' => [
          { 'id' => 292016360, 'name' => 'Mikey', 'handle' => 'mikeyclarke', 'user_id' => 4619740 },
          { 'id' => 292299371, 'name' => 'The Archived Stories', 'handle' => 'thearchivedstories', 'user_id' => 485689279 }
        ]
      })
    end

    it 'targets the immediate parent note, not the thread root or shared post' do
      expect(resolve.target_url).to eq 'https://substack.com/profile/485689279-thearchivedstories/note/c-292299371'
    end

    it 'attributes it to the immediate parent, not the grandparent' do
      expect(resolve.author_handle).to eq 'thearchivedstories'
    end
  end

  context 'a reply to a comment on a post (ancestor_path set, post present)' do
    let(:url) { 'https://pub.substack.com/p/some-post/comment/999' }

    before do
      allow(client).to receive(:get_note).with('999').and_return('item' => {
        'comment' => { 'ancestor_path' => '888', 'date' => 't' },
        'post' => { 'canonical_url' => 'https://pub.substack.com/p/some-post' },
        'parentComments' => [{ 'id' => 888, 'name' => 'Bob', 'handle' => 'bob', 'user_id' => 7 }]
      })
    end

    it { expect(resolve.target_url).to eq 'https://pub.substack.com/p/some-post/comment/888' }
    it { expect(resolve.author_handle).to eq 'bob' }
  end

  context 'a URL that is not a comment or note' do
    let(:url) { 'https://example.com/whatever' }

    it { expect { resolve }.to raise_error(ArgumentError, /comment or note/) }
  end
end
