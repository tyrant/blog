# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::Reposter do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: post, data: data }

  let(:data) do
    { 'blizzard' => [
      { 'uid' => 'e0', 'text' => 'hello', 'body_json' => { 'type' => 'doc' },
        'notes' => [{ 'url' => 'https://substack.com/profile/4619740-mikey-clarke/note/c-111', 'timestamp' => '2025-01-01T00:00:00Z' }] }
    ] }
  end

  let(:client) { instance_double(Substack::Client) }

  before do
    allow(client).to receive(:create_note).and_return('id' => 999, 'date' => '2026-06-19T00:00:00Z')
  end

  subject(:record) { described_class.execute(categorization: categorization, uid: 'e0', client: client) }

  it 'posts the stored body_json' do
    record
    expect(client).to have_received(:create_note).with({ 'type' => 'doc' })
  end

  it { expect(record['timestamp']).to eq '2026-06-19T00:00:00Z' }
  it 'builds the new URL from an existing note on the same profile' do
    expect(record['url']).to eq 'https://substack.com/profile/4619740-mikey-clarke/note/c-999'
  end

  it 'appends the new note to the group' do
    record
    expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 2
  end

  context 'unknown uid' do
    subject(:record) { described_class.execute(categorization: categorization, uid: 'nope', client: client) }
    it { expect { record }.to raise_error(ArgumentError) }
  end
end
