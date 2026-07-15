# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::DivergenceScanner do
  subject(:findings) { described_class.execute(client: client, pause: 0) }

  let(:client) { instance_double(Substack::Client) }
  let(:site) { create :site }
  let(:layout) { create :layout, site: site }
  let(:post) { create :post, site: site, layout: layout }
  let!(:categorization) do
    category = create :category, label: 'Substack', site: site
    create :categorization, category: category, categorized: post, data: { 'id' => 900 }
  end

  def image_node(size: nil, caption: nil)
    image = { 'type' => 'image2', 'attrs' => { 'src' => 'https://cdn/x.png', 'imageSize' => size }.compact }
    content = [image]
    content << { 'type' => 'caption', 'content' => [{ 'type' => 'text', 'text' => caption }] } if caption
    { 'type' => 'captionedImage', 'content' => content }
  end

  def substack_draft(*body_blocks)
    original = { 'type' => 'heading', 'content' => [{ 'type' => 'text', 'text' => 'Original: https://x' }] }
    { 'draft_body' => JSON.generate('content' => body_blocks + [original, { 'type' => 'button' }]) }
  end

  before do
    post.update_column(:content_cache, '<p>Body text</p>')
    allow(client).to receive(:get_draft).with(900).and_return(draft)
  end

  context 'a Substack image sized full with a caption' do
    let(:draft) { substack_draft({ 'type' => 'paragraph', 'content' => [] }, image_node(size: 'full', caption: 'A witty caption')) }

    it 'flags the width and caption divergences' do
      expect(findings.first.flags).to include('WIDTH', 'CAPTION')
    end

    it 'reports the non-normal sizes' do
      expect(findings.first.image_sizes).to eq(['full'])
    end

    it 'reports the caption text' do
      expect(findings.first.captions).to eq(['A witty caption'])
    end

    it 'notes the Substack image Comfy lacks' do
      expect(findings.first.flags).to include('IMG+1')
    end
  end

  context 'a Substack youtube embed Comfy lacks' do
    let(:draft) do
      substack_draft({ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Body text' }] },
                     { 'type' => 'youtube2', 'attrs' => { 'videoId' => 'abc' } })
    end

    it 'flags the video divergence' do
      expect(findings.first.flags).to include('VIDEO+1')
    end
  end

  context 'a draft that matches the Comfy rebuild' do
    let(:draft) { substack_draft({ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Body text' }] }) }

    it 'reports no flags' do
      expect(findings.first.flags).to be_empty
    end
  end

  context 'when a normal-sized image with no caption matches' do
    before { post.update_column(:content_cache, '<p><img src="http://x/a.jpg"></p>') }

    let(:draft) { substack_draft(image_node(size: 'normal')) }

    it 'does not flag width or caption' do
      expect(findings.first.flags).to_not include('WIDTH', 'CAPTION')
    end
  end
end
