# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do

  describe '#blizzard_note_links' do
    subject(:html) { helper.blizzard_note_links(notes) }

    let(:notes) do
      [
        { 'url' => 'https://substack.com/note/c-1', 'timestamp' => '2026-06-21T07:00:00Z' },
        { 'url' => 'https://substack.com/note/c-2', 'timestamp' => '2026-06-14T07:00:00Z' }
      ]
    end

    it { expect(html).to include 'href="https://substack.com/note/c-1"' }
    it { expect(html).to include 'href="https://substack.com/note/c-2"' }
    it { expect(html).to include '21 Jun 2026' }
    it { expect(html).to include 'target="_blank"' }
    it { expect(html).to include 'rel="noopener"' }
    it { expect(html).to include ' · ' }
    it { expect(html).to be_html_safe }

    context 'unparseable timestamp falls back to a positional label' do
      let(:notes) { [{ 'url' => 'u', 'timestamp' => 'gibberish' }] }
      it { expect(html).to include '#1' }
    end

    context 'missing timestamp falls back to a positional label' do
      let(:notes) { [{ 'url' => 'u' }] }
      it { expect(html).to include '#1' }
    end

    context 'no notes' do
      let(:notes) { [] }
      it { expect(html).to eq '' }
    end
  end
end
