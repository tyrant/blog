# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackEngagement do
  def row(user_id, key, kind, handle: nil, name: nil, at: '2026-10-01')
    { user_id: user_id, handle: handle, name: name, content_key: key, kind: kind, occurred_at: Time.zone.parse(at) }
  end

  describe '.record!' do
    it 'is idempotent per account, piece and kind' do
      2.times { described_class.record!([row(1, 'p-1', 'like'), row(1, 'p-1', 'like')]) }
      expect(described_class.count).to eq 1
    end

    it 'keeps a known handle and name when a later row has none' do
      described_class.record!([row(1, 'p-1', 'comment', handle: 'eva', name: 'Eva')])
      described_class.record!([row(1, 'p-1', 'comment')])
      expect(described_class.last.attributes.slice('handle', 'name')).to eq('handle' => 'eva', 'name' => 'Eva')
    end

    it 'does nothing with no rows' do
      expect { described_class.record!([]) }.not_to change(described_class, :count)
    end
  end

  describe '.leaderboard' do
    before do
      described_class.record!([row(1, 'p-1', 'comment', handle: 'eva', name: 'Eva', at: '2026-09-12'),
                               row(1, 'p-1', 'like', at: '2026-09-11'),
                               row(1, 'c-2', 'restack', at: '2026-10-15'),
                               row(1, 'c-3', 'reply', at: '2026-10-16'),
                               row(1, 'c-4', 'like', at: '2026-10-17')])
    end

    subject(:entry) { described_class.leaderboard.find_by(user_id: 1) }

    it 'counts each kind, pieces and active months' do
      expect([entry.comments, entry.likes, entry.restacks, entry.replies, entry.pieces, entry.active_months]).to eq [1, 2, 1, 1, 4, 2]
    end

    it 'scores pieces + 2 × non-likes + 3 × months' do
      expect(entry.score).to eq 4 + (2 * 3) + (3 * 2)
    end

    it 'carries the handle, name and latest date' do
      expect([entry.handle, entry.name, entry.last_engaged_at]).to eq ['eva', 'Eva', Time.zone.parse('2026-10-17')]
    end
  end

  describe '.suggestions' do
    before do
      described_class.record!((1..3).map { |i| row(10, "p-#{i}", 'like') })                       # 3 pieces
      described_class.record!((1..4).map { |i| row(20, "p-#{i}", 'comment') })                    # 4 pieces, more score
      described_class.record!((1..2).map { |i| row(30, "p-#{i}", 'comment') })                    # too few pieces
      described_class.record!((1..5).map { |i| row(40, "p-#{i}", 'like') })                       # me
      described_class.record!((1..5).map { |i| row(50, "p-#{i}", 'like') })                       # a favourite
      create :substack_user, user_id: 50, favourite: true
    end

    it 'ranks accounts with enough pieces, excluding me and existing favourites' do
      expect(described_class.suggestions(exclude_user_ids: [40]).map(&:user_id)).to eq [20, 10]
    end

    it 'orders by the chosen column' do
      described_class.record!([row(10, 'p-9', 'like', at: '2026-11-01')])
      expect(described_class.suggestions(order: 'last', exclude_user_ids: [40]).map(&:user_id).first).to eq 10
    end

    it 'falls back to score for an unknown column' do
      expect(described_class.suggestions(order: 'nope; drop', exclude_user_ids: [40]).map(&:user_id)).to eq [20, 10]
    end
  end

  describe '.profile_url' do
    it { expect(described_class.profile_url('eva', 1)).to eq 'https://substack.com/@eva' }
    it { expect(described_class.profile_url(nil, 1)).to eq 'https://substack.com/profile/1' }
  end
end
