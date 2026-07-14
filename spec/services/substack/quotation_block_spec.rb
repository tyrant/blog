# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::QuotationBlock do
  let(:quotation) do
    SubstackQuotation.new(quotation: 'a witty blurb', author_name: 'Eva', author_url: 'https://substack.com/@eva',
                          post_title: 'Chapter 19', post_url: 'https://x/p/ch19')
  end

  describe '.build' do
    subject(:block) { described_class.build(quotation) }

    it { expect(block['type']).to eq 'blockquote' }
    it { expect(described_class.paragraph_text(block['content'].first)).to eq '“a witty blurb”' }
    it { expect(described_class.paragraph_text(block['content'].last)).to eq 'By Eva, on Chapter 19' }

    it 'links the author to their profile' do
      node = block['content'].last['content'].find { |n| n['text'] == 'Eva' }
      expect(node.dig('marks', 0, 'attrs', 'href')).to eq 'https://substack.com/@eva'
    end

    it 'links the post title' do
      node = block['content'].last['content'].find { |n| n['text'] == 'Chapter 19' }
      expect(node.dig('marks', 0, 'attrs', 'href')).to eq 'https://x/p/ch19'
    end
  end

  describe '.matches?' do
    it { expect(described_class.matches?(described_class.build(quotation))).to be true }
    it { expect(described_class.matches?({ 'type' => 'paragraph' })).to be false }

    it 'ignores a real content blockquote without links' do
      bq = { 'type' => 'blockquote', 'content' => [{ 'type' => 'paragraph',
             'content' => [{ 'type' => 'text', 'text' => 'By the way, on Tuesdays I nap' }] }] }
      expect(described_class.matches?(bq)).to be false
    end
  end

  describe '.apply' do
    let(:content) { [{ 'type' => 'paragraph', 'content' => [] }, described_class.build(quotation)] }
    let(:other) do
      SubstackQuotation.new(quotation: 'a fresh one', author_name: 'Bob', author_url: 'https://x/@bob',
                            post_title: 'P', post_url: 'https://x/p')
    end

    it 'replaces an existing quotation block rather than stacking' do
      result = described_class.apply(content, other)
      expect(result.count { |b| described_class.matches?(b) }).to eq 1
    end

    it 'swaps in the new quotation text' do
      result = described_class.apply(content, other)
      expect(described_class.paragraph_text(result.last['content'].first)).to eq '“a fresh one”'
    end

    it 'appends at the very end' do
      result = described_class.apply([{ 'type' => 'paragraph', 'content' => [] }], quotation)
      expect(described_class.matches?(result.last)).to be true
    end

    it 'strips the block when there is no quotation' do
      expect(described_class.apply(content, nil).any? { |b| described_class.matches?(b) }).to be false
    end
  end
end
