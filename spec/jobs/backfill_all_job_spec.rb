# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BackfillAllJob do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:substack) { create :category, site: site, label: 'Substack' }
  let!(:other) { create :category, site: site, label: 'Whimsy' }
  let!(:substack_cat) { create :categorization, category: substack, categorized: post }
  let!(:other_cat) { create :categorization, category: other, categorized: post }

  before { allow_any_instance_of(described_class).to receive(:sleep) }

  it 'backfills each Substack categorization' do
    expect(Substack::Blizzard::Backfiller).to receive(:execute).with(hash_including(categorization: substack_cat, commit: true))
    described_class.perform_now
  end

  it 'skips non-Substack categorizations' do
    allow(Substack::Blizzard::Backfiller).to receive(:execute)
    described_class.perform_now
    expect(Substack::Blizzard::Backfiller).to_not have_received(:execute).with(hash_including(categorization: other_cat))
  end

  it 'finishes the progress row' do
    allow(Substack::Blizzard::Backfiller).to receive(:execute)
    described_class.perform_now
    expect(JobProgress.find_by(key: 'backfill_all').status).to eq 'finished'
  end
end
