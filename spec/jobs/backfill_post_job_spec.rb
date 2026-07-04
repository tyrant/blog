# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BackfillPostJob do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: post }

  it 'backfills the given categorization' do
    expect(Substack::Blizzard::Backfiller).to receive(:execute).with(hash_including(categorization: categorization, commit: true))
    described_class.perform_now(categorization.id)
  end

  it 'is a no-op for a missing categorization' do
    expect(Substack::Blizzard::Backfiller).to_not receive(:execute)
    described_class.perform_now(-1)
  end
end
