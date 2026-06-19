# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::DueFinder do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: post, data: data }

  def entry(text, *timestamps)
    { 'text' => text, 'body_json' => {}, 'notes' => timestamps.map { |t| { 'url' => 'u', 'timestamp' => t } } }
  end

  let(:data) do
    { 'blizzard' => [
      entry('fresh', 2.days.ago.iso8601),
      entry('stale', 90.days.ago.iso8601),
      entry('never')
    ] }
  end

  subject(:due) { described_class.execute(max_age_days: 14) }

  it { expect(due.map { |d| d.entry['text'] }).to contain_exactly('stale', 'never') }
  it { expect(due.find { |d| d.entry['text'] == 'stale' }.index).to eq 1 }
  it { expect(due.first.categorization).to eq categorization }

  context 'a generous window includes everything' do
    subject(:due) { described_class.execute(max_age_days: 1) }
    it { expect(due.size).to eq 3 }
  end

  context 'non-Substack categorizations are ignored' do
    let!(:other_cat) { create :category, site: site, label: 'Medium' }
    let!(:other) { create :categorization, category: other_cat, categorized: post, data: { 'blizzard' => [entry('x', 90.days.ago.iso8601)] } }
    it { expect(due.map(&:categorization)).to_not include(other) }
  end
end
