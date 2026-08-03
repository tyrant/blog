# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncAllSubstackPostsJob, type: :job do
  let!(:site) { create :site }
  let!(:category) { create :category, label: 'Substack', site: site }
  let!(:post_a) { create :post, site: site }
  let!(:post_b) { create :post, site: site }
  let!(:cat_a) { create :categorization, category: category, categorized: post_a, data: { 'id' => 900 } }
  let!(:cat_b) { create :categorization, category: category, categorized: post_b, data: { 'id' => 901 } }

  before { allow(SubstackPostSyncJob).to receive(:perform_later) }

  it 'enqueues a SubstackPostSyncJob for every Substack-linked post' do
    described_class.new.perform
    expect(SubstackPostSyncJob).to have_received(:perform_later).with(post_a.id)
  end

  it 'skips posts without a Substack categorization' do
    other = create :post, site: site
    described_class.new.perform
    expect(SubstackPostSyncJob).to_not have_received(:perform_later).with(other.id)
  end

  context 'when one enqueue errors' do
    before { allow(SubstackPostSyncJob).to receive(:perform_later).with(post_a.id).and_raise('boom') }

    it 'swallows the error and continues to the next post' do
      described_class.new.perform
      expect(SubstackPostSyncJob).to have_received(:perform_later).with(post_b.id)
    end
  end
end
