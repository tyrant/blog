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

    describe 'opening with a bold "another <compliment> review" heading' do
      let(:node) { doc['content'][0]['content'][0] }
      it { expect(node['text']).to eq 'Sexyverse Advice: another CRACKING review' }
      it { expect(node['marks'].map { |m| m['type'] }).to eq %w[bold] }
    end

    describe 'following the heading with a " (🔗"' do
      let(:node) { doc['content'][0]['content'][1] }
      it { expect(node['text']).to eq ' (🔗' }
      it { expect(node['marks']).to be_nil }
    end

    describe 'making the label @ an unbolded link to the original comment' do
      let(:node) { doc['content'][0]['content'][2] }
      let(:link) { 'https://pub.substack.com/p/ch-1/comment/42' }
      it { expect(node['text']).to eq link }
      it { expect(node['marks'].map { |m| m['type'] }).to eq %w[link] }
      it { expect(node['marks'].last.dig('attrs', 'href')).to eq link }
    end

    describe 'closing the label with a "):"' do
      let(:node) { doc['content'][0]['content'][3] }
      it { expect(node['text']).to eq '):' }
      it { expect(node['marks']).to be_nil }
    end

    describe 'dropping the compliment gracefully when none is configured' do
      before { allow(SubstackSyncConfig).to receive(:instance)
        .and_return(instance_double(SubstackSyncConfig, subtitle_variables: {})) }
      let(:node) { described_class.build(quote)['content'][0]['content'][0] }
      it { expect(node['text']).to eq 'Sexyverse Advice: another review' }
    end

    describe 'following with the post title as a bold link to the post' do
      let(:node) { doc['content'][1]['content'][0] }
      it { expect(node['text']).to eq 'Ch 1' }
      it { expect(node['marks'].map { |m| m['type'] }).to eq %w[bold link] }
      it { expect(node['marks'].last.dig('attrs', 'href')).to eq 'https://pub.substack.com/p/ch-1' }
    end

    describe 'italicising the quote inside a blockquote' do
      let(:node) { doc['content'][2]['content'][0]['content'][0] }
      it { expect(doc['content'][2]['type']).to eq 'blockquote' }
      it { expect(node['text']).to eq '“a blurb”' }
      it { expect(node['marks'].map { |m| m['type'] }).to eq %w[italic] }
    end

    describe 'keeping the 🔗 out of the quote blockquote' do
      let(:nodes) { doc['content'][2]['content'][0]['content'] }
      it { expect(nodes.none? { |n| n['text'] == '🔗' }).to be true }
    end

    describe 'attributing the quote to the linked author' do
      let(:block) { doc['content'][3] }
      it { expect(block['content'][1]['text']).to eq 'Eva' }
      it { expect(block['content'][1]['marks'].last.dig('attrs', 'href')).to eq 'https://substack.com/@eva' }
    end

    describe 'ending with a plain reviews-page line with the bare URL for Substack to auto-linkify' do
      let(:node) { doc['content'][4]['content'].first }
      it { expect(node['text']).to include "oodles more kudos at my Reviews Pages: (🔗" }
    end

    describe 'leaves the reviews-page URL unmarked (an explicit link mark gets stripped)' do
      let(:node) { doc['content'][4]['content'].first }
      it { expect(node['marks']).to be_nil }
    end
  end
end
