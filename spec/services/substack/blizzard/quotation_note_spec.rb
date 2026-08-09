# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::Blizzard::QuotationNote do
  def quote(attrs = {})
    SubstackQuotation.new({ quotation: 'a blurb', post_title: 'Ch 1',
                            post_url: 'https://pub.substack.com/p/ch-1',
                            comment_url: 'https://pub.substack.com/p/ch-1/comment/42',
                            author_name: 'Eva', author_url: 'https://substack.com/@eva' }.merge(attrs))
  end

  describe '.build' do
    subject(:doc) { described_class.build(quote) }

    before do
      allow(SubstackSyncConfig).to receive(:instance)
        .and_return(instance_double(SubstackSyncConfig, subtitle_variables: { 'compliment' => ['cracking'] }))
    end

    it { expect(doc['type']).to eq 'doc' }
    it { expect(doc['attrs']).to eq('schemaVersion' => 'v1') }

    it 'opens with a bold "Another <compliment> review" heading' do
      node = doc['content'][0]['content'][0]
      expect(node['text']).to eq 'Another cracking review'
      expect(node['marks'].map { |m| m['type'] }).to eq %w[bold]
    end

    it 'follows the heading with a " (@ "' do
      node = doc['content'][0]['content'][1]
      expect(node['text']).to eq ' (@ '
      expect(node['marks']).to be_nil
    end

    it 'makes the label @ an unbolded link to the original comment' do
      node = doc['content'][0]['content'][2]
      link = 'https://pub.substack.com/p/ch-1/comment/42'
      expect(node['text']).to eq link
      expect(node['marks'].map { |m| m['type'] }).to eq %w[link]
      expect(node['marks'].last.dig('attrs', 'href')).to eq link
    end

    it 'closes the label with a "):"' do
      node = doc['content'][0]['content'][3]
      expect(node['text']).to eq '):'
      expect(node['marks']).to be_nil
    end

    it 'drops the compliment gracefully when none is configured' do
      allow(SubstackSyncConfig).to receive(:instance)
        .and_return(instance_double(SubstackSyncConfig, subtitle_variables: {}))
      node = described_class.build(quote)['content'][0]['content'][0]
      expect(node['text']).to eq 'Another review'
    end

    it 'follows with the post title as a bold link to the post' do
      node = doc['content'][1]['content'][0]
      expect(node['text']).to eq 'Ch 1'
      expect(node['marks'].map { |m| m['type'] }).to eq %w[bold link]
      expect(node['marks'].last.dig('attrs', 'href')).to eq 'https://pub.substack.com/p/ch-1'
    end

    it 'italicises the quote inside a blockquote' do
      node = doc['content'][2]['content'][0]['content'][0]
      expect(doc['content'][2]['type']).to eq 'blockquote'
      expect(node['text']).to eq '“a blurb”'
      expect(node['marks'].map { |m| m['type'] }).to eq %w[italic]
    end

    it 'keeps the 🔗 out of the quote blockquote' do
      nodes = doc['content'][2]['content'][0]['content']
      expect(nodes.none? { |n| n['text'] == '🔗' }).to be true
    end

    it 'attributes the quote to the linked author' do
      block = doc['content'][3]
      expect(block['content'].last['text']).to eq 'Eva'
      expect(block['content'].last['marks'].last.dig('attrs', 'href')).to eq 'https://substack.com/@eva'
    end

    it 'ends with a plain reviews-page line with the bare URL for Substack to auto-linkify' do
      node = doc['content'][4]['content'].first
      expect(node['text']).to include "oodles more kudos at my Reviews Page (#{described_class::REVIEWS_URL})"
    end

    it 'leaves the reviews-page URL unmarked (an explicit link mark gets stripped)' do
      node = doc['content'][4]['content'].first
      expect(node['marks']).to be_nil
    end
  end
end
