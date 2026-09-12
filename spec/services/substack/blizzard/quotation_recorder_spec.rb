# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::QuotationRecorder do

  let!(:quotation) { SubstackQuotation.create!(quotation: 'a gem', comment_url: 'https://x/comment/1') }
  let(:url) { 'https://substack.com/@m/note/c-9' }

  def record(u = url)
    described_class.execute(quotation_id: quotation.id, url: u, timestamp: '2026-07-04T00:00:00Z')
  end

  it 'appends the note seeded with zero likes' do
    record
    note = quotation.reload.notes.last
    expect(note).to include('url' => url, 'timestamp' => '2026-07-04T00:00:00Z', 'likes' => 0)
  end

  it 'is idempotent by url' do
    record
    record
    expect(quotation.reload.notes.size).to eq 1
  end

  context 'blank url' do
    before { described_class.execute(quotation_id: quotation.id, url: '', timestamp: '2026-07-04T00:00:00Z') }
    it { expect(quotation.reload.notes).to be_empty }
  end

  context 'blank timestamp' do
    before { described_class.execute(quotation_id: quotation.id, url: url, timestamp: '') }
    it { expect(quotation.reload.notes).to be_empty }
  end

  context 'unknown quotation_id' do
    it 'does not raise' do
      expect { described_class.execute(quotation_id: -1, url: url, timestamp: '2026-07-04T00:00:00Z') }.to_not raise_error
    end
  end
end
