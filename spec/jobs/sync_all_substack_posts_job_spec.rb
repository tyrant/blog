# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncAllSubstackPostsJob, type: :job do
  let!(:site) { create :site }
  let!(:category) { create :category, label: 'Substack', site: site }
  let!(:post_a) { create :post, site: site }
  let!(:post_b) { create :post, site: site }
  let!(:cat_a) { create :categorization, category: category, categorized: post_a, data: { 'id' => 900 } }
  let!(:cat_b) { create :categorization, category: category, categorized: post_b, data: { 'id' => 901 } }

  before do
    allow(Substack::PostSyncer).to receive(:execute)
    allow_any_instance_of(described_class).to receive(:sleep)
  end

  it 'syncs every Substack-linked post' do
    described_class.new.perform
    expect(Substack::PostSyncer).to have_received(:execute).with(post_id: post_a.id)
  end

  it 'skips posts without a Substack categorization' do
    other = create :post, site: site
    described_class.new.perform
    expect(Substack::PostSyncer).to_not have_received(:execute).with(post_id: other.id)
  end

  context 'when one post errors' do
    before { allow(Substack::PostSyncer).to receive(:execute).with(post_id: post_a.id).and_raise('boom') }

    it 'swallows the error and continues to the next post' do
      described_class.new.perform
      expect(Substack::PostSyncer).to have_received(:execute).with(post_id: post_b.id)
    end
  end
end
