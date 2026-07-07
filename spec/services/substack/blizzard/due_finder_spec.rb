# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::DueFinder do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: post, data: data }

  def entry(text, *timestamps)
    { 'uid' => text, 'text' => text, 'body_json' => {}, 'notes' => timestamps.map { |t| { 'url' => 'u', 'timestamp' => t } } }
  end

  let(:data) do
    { 'blizzard' => [
      entry('fresh', 2.days.ago.iso8601),
      entry('stale', 90.days.ago.iso8601),
      entry('never')
    ] }
  end

  subject(:due) { described_class.execute(max_age_days: 14) }

  it 'orders most-stale-first (never-posted, then oldest)' do
    expect(due.map { |d| d.entry['text'] }).to eq %w[never stale]
  end
  it { expect(due.find { |d| d.entry['text'] == 'stale' }.uid).to eq 'stale' }
  it { expect(due.first.categorization).to eq categorization }

  context 'a generous window includes everything' do
    subject(:due) { described_class.execute(max_age_days: 1) }
    it { expect(due.size).to eq 3 }
  end

  context 'max_age_days: 0 includes every posted/never group' do
    subject(:due) { described_class.execute(max_age_days: 0) }
    it { expect(due.map { |d| d.entry['text'] }).to contain_exactly('never', 'stale', 'fresh') }
  end

  context 'title_query filters by post title (case-insensitive)' do
    let!(:post) { create :post, site: site, title: 'Chicken PMS' }
    let!(:other_post) { create :post, site: site, title: 'Soy Milk', slug: 'soy' }
    let!(:other) { create :categorization, category: category, categorized: other_post, data: { 'blizzard' => [entry('o', 90.days.ago.iso8601)] } }

    it 'keeps only matching-title categorizations' do
      due = described_class.execute(max_age_days: 14, title_query: 'chick')
      expect(due.map(&:categorization).uniq).to eq [categorization]
    end

    it { expect(described_class.execute(max_age_days: 14, title_query: 'zzz')).to be_empty }
    it { expect(described_class.execute(max_age_days: 14, title_query: '').size).to eq 3 }
  end

  context 'non-Substack categorizations are ignored' do
    let!(:other_cat) { create :category, site: site, label: 'Medium' }
    let!(:other) { create :categorization, category: other_cat, categorized: post, data: { 'blizzard' => [entry('x', 90.days.ago.iso8601)] } }
    it { expect(due.map(&:categorization)).to_not include(other) }
  end
end
