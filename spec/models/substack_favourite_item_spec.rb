# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackFavouriteItem do
  let(:user) { create :substack_user, favourite: true }

  def item(key, kind: 'note', url: "https://substack.com/@x/note/#{key}", at: 2.days.ago, **attrs)
    described_class.create!(substack_user: user, entity_key: key, kind: kind, url: url, published_at: at, **attrs)
  end

  describe 'scopes' do
    let!(:old) { item('c-1', at: 3.days.ago) }
    let!(:new) { item('c-2', at: 1.day.ago) }
    let!(:done) { item('c-3', dismissed_at: Time.current) }

    it { expect(described_class.pending.newest_first).to eq [new, old] }

    it 'only lists current favourites' do
      user.update!(favourite: false)
      expect(described_class.from_favourites).to be_empty
    end
  end

  it { expect(item('c-5').comment_id).to eq '5' }
  it { expect(item('p-5', kind: 'post', url: 'https://x.substack.com/p/y').comment_id).to be_nil }
  it { expect(described_class.new(kind: 'video')).not_to be_valid }

  describe '.replied_ids' do
    let!(:note) { item('c-100') }
    let!(:nested) { item('c-200') }
    let!(:post) { item('p-7', kind: 'post', url: 'https://x.substack.com/p/y') }
    let!(:untouched) { item('c-300') }

    before do
      SubstackReply.create!(target_url: 'https://substack.com/@x/note/c-100', comment_url: 'https://substack.com/@me/note/c-1', replied_at: 1.day.ago)
      SubstackReply.create!(target_url: 'https://substack.com/@x/note/c-999', comment_url: 'https://substack.com/@me/note/c-2', replied_at: 1.day.ago, ancestor_path: '200.999')
      SubstackReply.create!(target_url: 'https://x.substack.com/p/y/comment/5', comment_url: 'https://x.substack.com/p/y/comment/6', replied_at: 1.day.ago)
    end

    it 'finds Notes replied to directly or within the thread, and commented-on posts' do
      expect(described_class.replied_ids(described_class.all)).to eq Set[note.id, nested.id, post.id]
    end

    it { expect(described_class.replied_ids([])).to eq Set.new }
  end
end
