# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::TemplateBoundary do
  def heading(text, align: nil, link: false)
    node = { 'type' => 'text', 'text' => text }
    node['marks'] = [{ 'type' => 'link', 'attrs' => { 'href' => 'https://x' } }] if link
    { 'type' => 'heading', 'attrs' => { 'textAlign' => align, 'level' => 5 }, 'content' => [node] }
  end

  let(:body) { [{ 'type' => 'paragraph' }, heading('Body heading')] }

  let(:divider) { { 'type' => 'horizontal_rule' } }
  let(:links_section) { [heading('.', align: 'center'), heading('This post also moonwalks resplendent twixt', align: 'center'), heading('My website', align: 'center', link: true)] }

  describe '.index' do
    it 'starts at the divider above the THANK YOU heading, with the links section at the end' do
      content = body + [divider, heading('😘 THANK YOU 😘', align: 'center'), { 'type' => 'paragraph' }] + links_section
      expect(described_class.index(content)).to eq 2
    end

    it 'starts at the THANK YOU heading itself when no divider sits above it' do
      content = body + [heading('😘 THANK YOU 😘'), { 'type' => 'paragraph' }]
      expect(described_class.index(content)).to eq 2
    end

    it 'ignores body dividers that are not directly above THANK YOU' do
      content = [divider] + body + [divider, heading('😘 THANK YOU 😘')]
      expect(described_class.index(content)).to eq 3
    end

    it 'still splits an older links-first draft at the links section' do
      content = body + links_section + [divider, heading('😘 THANK YOU 😘')]
      expect(described_class.index(content)).to eq 2
    end

    it 'still splits a legacy Original:-first draft at the Original heading' do
      content = body + [heading('Original: https://x'), { 'type' => 'button' }, divider, heading('😘 THANK YOU 😘')]
      expect(described_class.index(content)).to eq 2
    end

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
