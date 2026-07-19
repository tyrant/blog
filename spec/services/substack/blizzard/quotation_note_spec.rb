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

    it { expect(doc['type']).to eq 'doc' }
    it { expect(doc['attrs']).to eq('schemaVersion' => 'v1') }

    it 'opens with a bold "Review:" label' do
      node = doc['content'][0]['content'][0]
      expect(node['text']).to eq 'Review:'
      expect(node['marks'].map { |m| m['type'] }).to eq %w[bold]
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

    it 'trails the quote with a 🔗 linking the original comment' do
      link = doc['content'][2]['content'][0]['content'].last
      expect(link['text']).to eq '🔗'
      expect(link.dig('marks', 0, 'attrs', 'href')).to eq 'https://pub.substack.com/p/ch-1/comment/42'
    end

    it 'omits the comment link when there is no comment_url' do
      nodes = described_class.build(quote(comment_url: nil))['content'][2]['content'][0]['content']
      expect(nodes.none? { |n| n['text'] == '🔗' }).to be true
    end

    it 'attributes the quote to the linked author' do
      block = doc['content'][3]
      expect(block['content'].last['text']).to eq 'Eva'
      expect(block['content'].last['marks'].last.dig('attrs', 'href')).to eq 'https://substack.com/@eva'
    end

    it 'ends with a "More reviews" line linking the reviews page' do
      block = doc['content'][4]
      expect(block['content'].first['text']).to eq 'More reviews at '
      link = block['content'].last
      expect(link['text']).to eq described_class::REVIEWS_URL
      expect(link['marks'].last.dig('attrs', 'href')).to eq described_class::REVIEWS_URL
    end
  end
end
