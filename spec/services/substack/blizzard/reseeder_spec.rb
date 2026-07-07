# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::Reseeder do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) do
    create :categorization, category: category, categorized: post,
           url: 'https://mikeyclarke.substack.com/p/foo', data: data
  end

  let(:data) do
    { 'blizzard' => [
      { 'uid' => 'e0', 'text' => 'plain', 'body_json' => { 'type' => 'doc', 'content' => [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'plain' }] }] },
        'notes' => [{ 'url' => 'https://substack.com/profile/x/note/c-111', 'timestamp' => '2025-01-01T00:00:00Z' }] }
    ] }
  end

  let(:client) { instance_double(Substack::Client) }
  let(:rich_body) do
    { 'type' => 'doc', 'content' => [
      { 'type' => 'paragraph', 'content' => [
        { 'type' => 'text', 'text' => 'rich ' },
        { 'type' => 'text', 'text' => 'bold', 'marks' => [{ 'type' => 'bold' }] }
      ] }
    ] }
  end

  before { allow(client).to receive(:get_note).and_return('comment' => { 'body_json' => rich_body }) }

  subject(:run) do
    described_class.execute(categorization: categorization, uid: 'e0',
                            note_url: 'https://substack.com/@mikeyclarke/note/c-999', client: client)
  end

  it 'reads the pasted note' do
    run
    expect(client).to have_received(:get_note).with('999')
  end

  it 'replaces body_json with the rich content' do
    run
    expect(categorization.reload.data['blizzard'][0]['body_json']['content'].first['content']).to include(a_hash_including('marks' => [{ 'type' => 'bold' }]))
  end

  it 'regenerates text from the new body_json' do
    run
    expect(categorization.reload.data['blizzard'][0]['text']).to start_with 'rich bold'
  end

  it 'appends the post URL to the re-seeded body' do
    run
    hrefs = Substack::NoteParser.link_hrefs(categorization.reload.data['blizzard'][0]['body_json'])
    expect(hrefs).to include 'https://mikeyclarke.substack.com/p/foo'
  end

  it 'leaves the notes history untouched' do
    run
    expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 1
  end

  context 'the note has no body' do
    before { allow(client).to receive(:get_note).and_return('comment' => {}) }
    it { expect { run }.to raise_error(/no readable body/) }
    it 'does not wipe the existing body_json' do
      run rescue nil
      expect(categorization.reload.data['blizzard'][0]['text']).to eq 'plain'
    end
  end

  context 'not a note URL' do
    subject(:run) do
      described_class.execute(categorization: categorization, uid: 'e0', note_url: 'https://example.com/x', client: client)
    end
    it { expect { run }.to raise_error(/Not a Substack note URL/) }
  end

  context 'unknown uid' do
    subject(:run) do
      described_class.execute(categorization: categorization, uid: 'nope', note_url: 'https://substack.com/@m/note/c-1', client: client)
    end
    it { expect { run }.to raise_error(ArgumentError, /No blizzard entry/) }
  end
end
