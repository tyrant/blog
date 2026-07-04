# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::ForecastData do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site, title: 'A Post' }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: post, url: 'https://sub.example/p/a', data: data }

  def entry(text, *timestamps)
    { 'text' => text, 'body_json' => {}, 'notes' => timestamps.map { |t| { 'url' => 'u', 'timestamp' => t } } }
  end

  let(:posted_at) { 30.days.ago }
  let(:data) do
    { 'blizzard' => [
      entry('posted group', 90.days.ago.iso8601, posted_at.iso8601),
      entry('never posted')
    ] }
  end

  subject(:payload) { described_class.execute }

  describe '#execute' do
    it { expect(payload.size).to eq 2 }

    describe 'a posted group' do
      let(:group) { payload.find { |g| g[:content] == 'posted group' } }

      it { expect(Time.zone.parse(group[:anchor])).to be_within(1.second).of posted_at }
      it { expect(group[:title]).to eq 'A Post' }
      it { expect(group[:url]).to eq 'https://sub.example/p/a' }
      # camelCase keys: this payload is consumed directly by the TS controller.
      it { expect(group[:categorizationId]).to eq categorization.id }
      it { expect(group[:entryIndex]).to eq 0 }
    end

    describe 'a never-posted group' do
      let(:group) { payload.find { |g| g[:content] == 'never posted' } }

      it { expect(group[:anchor]).to be_nil }
    end

    describe 'the full note content for the tooltip' do
      let(:full_text) { "#{'word ' * 40}end" }
      let(:data) { { 'blizzard' => [entry(full_text)] } }

      it { expect(payload.first[:content]).to eq full_text }
    end

    describe 'ignores non-Substack categorizations' do
      let!(:other_category) { create :category, site: site, label: 'Whimsy' }
      let!(:other) { create :categorization, category: other_category, categorized: post, data: { 'blizzard' => [entry('whimsy group')] } }

      it { expect(payload.map { |g| g[:content] }).to_not include 'whimsy group' }
    end
  end
end
