# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bluesky::TeaserBuilder do
  subject(:teaser) { described_class.execute(post: post, url: url, lead: lead) }

  let(:post) { double(title: title) }
  let(:title) { 'My Post' }
  let(:url) { 'https://blog.example/p/1' }
  let(:lead) { 'New on the blog' }

  describe 'text' do
    it 'joins the lead, title and url with blank lines' do
      expect(teaser[:text]).to eq "New on the blog\n\nMy Post\n\nhttps://blog.example/p/1"
    end

    context 'with no lead' do
      let(:lead) { '' }

      it { expect(teaser[:text]).to eq "My Post\n\nhttps://blog.example/p/1" }
    end
  end

  describe 'link facet' do
    subject(:facet) { teaser[:facets].first }

    it 'marks the url as a link feature' do
      expect(facet['features']).to eq [{ '$type' => 'app.bsky.richtext.facet#link', 'uri' => url }]
    end

    it 'indexes the url by its UTF-8 byte offset' do
      byte_start = "New on the blog\n\nMy Post\n\n".bytesize
      expect(facet['index']).to eq('byteStart' => byte_start, 'byteEnd' => byte_start + url.bytesize)
    end

    context 'with a multibyte lead' do
      let(:lead) { '🎉' }

      it 'counts bytes, not characters, for the offset' do
        expect(facet['index']['byteStart']).to eq "🎉\n\nMy Post\n\n".bytesize
      end
    end
  end

  describe 'a title longer than the grapheme limit' do
    let(:title) { 'A' * 400 }

    it 'keeps the whole teaser within 300 graphemes' do
      expect(teaser[:text].grapheme_clusters.length).to be <= 300
    end

    it 'truncates the prefix with an ellipsis' do
      expect(teaser[:text]).to include '…'
    end

    it 'keeps the url intact at the end' do
      expect(teaser[:text]).to end_with url
    end

    it 'still indexes the url correctly after truncation' do
      facet = teaser[:facets].first
      expect(teaser[:text].byteslice(facet['index']['byteStart'], url.bytesize)).to eq url
    end
  end
end
