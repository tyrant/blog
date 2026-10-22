# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::TemplateBoundary do
  def heading(text, align: nil, link: false)
    node = { 'type' => 'text', 'text' => text }
    node['marks'] = [{ 'type' => 'link', 'attrs' => { 'href' => 'https://x' } }] if link
    { 'type' => 'heading', 'attrs' => { 'textAlign' => align, 'level' => 5 }, 'content' => [node] }
  end

  let(:body) { [{ 'type' => 'paragraph' }, heading('Body heading')] }

  describe '.index' do
    it 'starts at the centred lead-in headings above the My website links row' do
      content = body + [heading('.', align: 'center'), heading('This post ALSO', align: 'center'), heading('My website', align: 'center', link: true)]
      expect(described_class.index(content)).to eq 2
    end

    it 'does not pull in unaligned body headings' do
      content = body + [heading('My website', align: 'center', link: true)]
      expect(described_class.index(content)).to eq 2
    end

    it 'falls back to a legacy Original: heading' do
      content = body + [heading('Original: https://x')]
      expect(described_class.index(content)).to eq 2
    end

    it 'is nil when neither marker is present' do
      expect(described_class.index(body)).to be_nil
    end
  end
end
