# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackSubscription do

  describe '#publication_url' do
    it { expect(build(:substack_subscription, publication_subdomain: 'eva').publication_url).to eq 'https://eva.substack.com' }
    it { expect(build(:substack_subscription, publication_custom_domain: 'eva.example').publication_url).to eq 'https://eva.example' }
  end

  describe '#profile_url' do
    it { expect(build(:substack_subscription, author_handle: 'eva').profile_url).to eq 'https://substack.com/@eva' }
    it { expect(build(:substack_subscription, author_handle: nil).profile_url).to be_nil }
  end

  describe '#paid?' do
    it { expect(build(:substack_subscription, membership_state: 'subscribed').paid?).to be true }
    it { expect(build(:substack_subscription).paid?).to be false }
  end

  describe '.with_interaction_counts' do
    let!(:subscription) { create :substack_subscription, author_id: 42 }
    let!(:user) { create :substack_user, user_id: 42 }

    before do
      SubstackQuotation.create!(quotation: 'q', comment_url: 'https://x/comment/1', substack_user: user)
      SubstackReply.create!(target_url: 'https://x/p/y', comment_url: 'https://x/comment/2', replied_at: Time.current, substack_user: user)
    end

    subject(:counted) { described_class.with_interaction_counts.find(subscription.id) }

    it { expect(counted.quotations_count).to eq 1 }
    it { expect(counted.replies_count).to eq 1 }
  end

  describe '.candidates' do
    let!(:candidate) { create :substack_subscription, :checked }
    let!(:follower) { create :substack_subscription, :checked, follows_me: true }
    let!(:subscriber) { create :substack_subscription, :checked, subscribes_to_me: true }
    let!(:paid) { create :substack_subscription, :checked, membership_state: 'subscribed' }
    let!(:unchecked) { create :substack_subscription }
    let!(:failed) { create :substack_subscription, :checked, check_error: 'boom' }
    let!(:quoted) { create :substack_subscription, :checked, author_id: 42 }
    let!(:replied) { create :substack_subscription, :checked, author_id: 43 }

    before do
      SubstackQuotation.create!(quotation: 'q', comment_url: 'https://x/comment/1', substack_user: create(:substack_user, user_id: 42))
      SubstackReply.create!(target_url: 't', comment_url: 'https://x/comment/2', replied_at: Time.current, substack_user: create(:substack_user, user_id: 43))
    end

    it { expect(described_class.candidates.to_a).to eq [candidate] }
  end

  describe '.filtered' do
    let!(:candidate) { create :substack_subscription, :checked }
    let!(:follower) { create :substack_subscription, :checked, follows_me: true }
    let!(:unchecked) { create :substack_subscription }
    let!(:failed) { create :substack_subscription, :checked, check_error: 'boom' }

    it { expect(described_class.filtered('candidates').to_a).to eq [candidate] }
    it { expect(described_class.filtered('follows_back').to_a).to eq [follower] }
    it { expect(described_class.filtered('unchecked').to_a).to eq [unchecked] }
    it { expect(described_class.filtered('errors').to_a).to eq [failed] }
    it { expect(described_class.filtered('all').count).to eq 4 }
    it { expect(described_class.filtered('bogus').to_a).to eq [candidate] }
  end

  describe '.search' do
    let!(:eva) { create :substack_subscription, publication_name: 'Eva Writes', author_handle: 'evasolen' }
    let!(:bob) { create :substack_subscription, publication_name: 'Bob Blogs', author_handle: 'bob' }

    it { expect(described_class.search('writes').to_a).to eq [eva] }
    it { expect(described_class.search('@EVASOLEN').to_a).to eq [eva] }
    it { expect(described_class.search('').count).to eq 2 }
  end

  describe '.sorted_by' do
    let!(:old) { create :substack_subscription, publication_name: 'Zed', subscribed_at: 2.years.ago, author_follower_count: 10 }
    let!(:recent) { create :substack_subscription, publication_name: 'amy', subscribed_at: 1.day.ago, author_follower_count: nil }

    it { expect(described_class.sorted_by(nil, nil).to_a).to eq [recent, old] }
    it { expect(described_class.sorted_by('publication', 'asc').to_a).to eq [recent, old] }
    it { expect(described_class.sorted_by('followers', 'asc').to_a).to eq [old, recent] }
    it { expect(described_class.sorted_by('bogus', 'asc').to_a).to eq [old, recent] }
  end
end
