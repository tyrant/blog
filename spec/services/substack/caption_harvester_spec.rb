# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::CaptionHarvester do
  let(:client) { instance_double(Substack::Client) }
  let(:site) { create :site }
  let(:layout) { create :layout, site: site }
  let(:post) { create :post, site: site, layout: layout }
  let!(:fragment) do
    create :fragment, record: post, identifier: 'content',
                      content: '<p><img src="http://x/a.jpg"></p><p>A witty caption.</p><p>Body text.</p>'
  end
  let!(:categorization) do
    category = create :category, label: 'Substack', site: site
    create :categorization, category: category, categorized: post, data: { 'id' => 900 }
  end

  def draft_with_caption(text)
    img = { 'type' => 'captionedImage', 'content' => [
      { 'type' => 'image2', 'attrs' => {} },
      { 'type' => 'caption', 'content' => [{ 'type' => 'text', 'text' => text }] }
    ] }
    { 'draft_body' => JSON.generate('content' => [img]) }
  end

  before { allow(client).to receive(:get_draft).with(900).and_return(draft_with_caption('A witty caption.')) }

  context 'dry run' do
    subject(:results) { described_class.execute(client: client, pause: 0, commit: false) }

    it 'reports the caption would be marked' do
      expect(results.first.marked).to eq 1
    end

    it 'does not write to the fragment' do
      results
      expect(fragment.reload.content).to_not include('class="caption"')
    end
  end

  context 'commit' do
    subject(:harvest) { described_class.execute(client: client, pause: 0, commit: true) }

    it 'marks only the matching caption paragraph' do
      harvest
      captioned = Nokogiri::HTML.fragment(fragment.reload.content).css('p.caption')
      expect(captioned.map(&:text)).to eq(['A witty caption.'])
    end

    it 'clears the content cache so it regenerates' do
      post.update_column(:content_cache, '<cached/>')
      harvest
      expect(post.reload.read_attribute(:content_cache)).to be_nil
    end
  end

  context 'when the Substack caption was edited away from the paragraph' do
    subject(:results) { described_class.execute(client: client, pause: 0, commit: true) }

    before { allow(client).to receive(:get_draft).with(900).and_return(draft_with_caption('An edited, diverged caption.')) }

    it 'marks nothing and reports it unmatched' do
      results
      expect(results.first).to have_attributes(marked: 0, unmatched: ['An edited, diverged caption.'])
    end
  end
end
