# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::Backfiller do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) do
    create :categorization, category: category, categorized: post,
           url: 'https://mikeyclarke.substack.com/p/canonical', data: data
  end

  let(:data) { { 'notes' => note_urls } }
  let(:note_urls) { [] }

  let(:client) { instance_double(Substack::Client) }

  # Maps comment id => fetched payload. body built from text (+ optional post link).
  let(:notes_by_id) { {} }

  def note_url(id)  = "https://substack.com/profile/4619740-mikey-clarke/note/c-#{id}"
  def body(text, href: 'https://mikeyclarke.substack.com/p/canonical')
    marks = href ? [{ 'type' => 'link', 'attrs' => { 'href' => href } }] : []
    { 'type' => 'doc', 'content' => [
      { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => text, 'marks' => marks }] }
    ] }
  end

  before do
    allow(client).to receive(:get_note) { |id| { 'comment' => notes_by_id.fetch(id.to_s) } }
  end

  subject(:run) { described_class.execute(categorization: categorization, client: client) }

  describe 'grouping' do
    let(:note_urls) { [note_url(111), note_url(222), note_url(333)] }
    let(:notes_by_id) do
      {
        '111' => { 'body_json' => body('Same text'), 'date' => '2025-01-01T00:00:00Z' },
        '222' => { 'body_json' => body('Same text'), 'date' => '2025-02-01T00:00:00Z' },
        '333' => { 'body_json' => body('Different'),  'date' => '2025-03-01T00:00:00Z' }
      }
    end

    before { run }

    let(:blizzard) { categorization.reload.data['blizzard'] }

    it { expect(blizzard.size).to eq 2 }
    it { expect(blizzard.find { |e| e['text'] == 'Same text' }['notes'].size).to eq 2 }
    it { expect(blizzard.find { |e| e['text'] == 'Different' }['notes'].size).to eq 1 }
    it { expect(blizzard.first['notes'].first).to eq({ 'url' => note_url(111), 'timestamp' => '2025-01-01T00:00:00Z' }) }
    it { expect(blizzard.first['body_json']).to eq body('Same text') }
  end

  describe 'data["notes"] is left untouched' do
    let(:note_urls) { [note_url(111)] }
    let(:notes_by_id) { { '111' => { 'body_json' => body('x'), 'date' => 't' } } }

    before { run }

    it { expect(categorization.reload.data['notes']).to eq note_urls }
  end

  describe 'idempotency' do
    let(:note_urls) { [note_url(111)] }
    let(:notes_by_id) { { '111' => { 'body_json' => body('x'), 'date' => 't' } } }

    before { 2.times { described_class.execute(categorization: categorization, client: client) } }

    it { expect(categorization.reload.data['blizzard'].sum { |e| e['notes'].size }).to eq 1 }
  end

  describe 'commit: false does not persist' do
    let(:note_urls) { [note_url(111)] }
    let(:notes_by_id) { { '111' => { 'body_json' => body('x'), 'date' => 't' } } }

    before { described_class.execute(categorization: categorization, client: client, commit: false) }

    it { expect(categorization.reload.data['blizzard']).to be_nil }
  end

  describe 'wrong-URL flag' do
    let(:note_urls) { [note_url(111)] }
    let(:notes_by_id) do
      { '111' => { 'body_json' => body('x', href: 'https://mikeyclarke.substack.com/p/SOMETHING-ELSE'), 'date' => 't' } }
    end

    it { expect(run.flags).to include(a_string_matching(/not canonical/)) }
  end

  describe 'note that links to the canonical post is not flagged' do
    let(:note_urls) { [note_url(111)] }
    let(:notes_by_id) { { '111' => { 'body_json' => body('x'), 'date' => 't' } } }

    it { expect(run.flags).to be_empty }
  end
end
