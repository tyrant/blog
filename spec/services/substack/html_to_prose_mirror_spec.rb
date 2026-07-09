# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::HtmlToProseMirror do
  subject(:doc) { described_class.execute(html: html, image_resolver: resolver) }

  let(:resolver) { ->(src) { "cdn:#{src}" } }
  let(:content) { doc['content'] }

  describe 'document shape' do
    let(:html) { '<p>Hello</p>' }

    it { expect(doc['type']).to eq 'doc' }
    it { expect(content.first['type']).to eq 'paragraph' }
    it { expect(content.first['content'].first).to eq({ 'type' => 'text', 'text' => 'Hello' }) }
  end

  describe 'headings' do
    let(:html) { '<h2>Title</h2>' }

    it { expect(content.first['type']).to eq 'heading' }
    it { expect(content.first['attrs']['level']).to eq 2 }
    it { expect(content.first['content'].first['text']).to eq 'Title' }
  end

  describe 'inline marks' do
    let(:html) { '<p>a <strong>b</strong> <em>c</em> <a href="http://x.com">d</a></p>' }
    let(:texts) { content.first['content'] }

    it { expect(texts.find { |n| n['text'] == 'b' }['marks']).to eq [{ 'type' => 'strong' }] }
    it { expect(texts.find { |n| n['text'] == 'c' }['marks']).to eq [{ 'type' => 'em' }] }

    it 'carries the link href' do
      link = texts.find { |n| n['text'] == 'd' }
      expect(link['marks']).to eq [{ 'type' => 'link', 'attrs' => { 'href' => 'http://x.com', 'title' => nil } }]
    end
  end

  describe 'bullet list' do
    let(:html) { '<ul><li>one</li><li>two</li></ul>' }
    let(:node) { content.first }

    it { expect(node['type']).to eq 'bullet_list' }
    it { expect(node['content'].map { |i| i['type'] }).to eq %w[list_item list_item] }
    it { expect(node['content'].first['content'].first['type']).to eq 'paragraph' }
    it { expect(node['content'].first['content'].first['content'].first['text']).to eq 'one' }
  end

  describe 'ordered list' do
    let(:html) { '<ol><li>one</li></ol>' }

    it { expect(content.first['type']).to eq 'ordered_list' }
    it { expect(content.first['attrs']).to eq({ 'order' => 1, 'tight' => false }) }
  end

  describe 'blockquote' do
    let(:html) { '<blockquote>quoted</blockquote>' }

    it { expect(content.first['type']).to eq 'blockquote' }
    it { expect(content.first['content'].first['type']).to eq 'paragraph' }
    it { expect(content.first['content'].first['content'].first['text']).to eq 'quoted' }
  end

  describe 'images' do
    let(:html) { '<p><img src="http://x.com/a.jpg" alt="pic"></p>' }
    let(:node) { content.first }

    it { expect(node['type']).to eq 'captionedImage' }
    it { expect(node['content'].first['type']).to eq 'image2' }
    it { expect(node['content'].first['attrs']['src']).to eq 'cdn:http://x.com/a.jpg' }
    it { expect(node['content'].first['attrs']['alt']).to eq 'pic' }

    context 'when the resolver drops the image' do
      let(:resolver) { ->(_src) { nil } }

      it { expect(content).to be_empty }
    end
  end

  describe 'unknown elements' do
    context 'inline wrapper is unwrapped' do
      let(:html) { '<p><span>kept</span></p>' }

      it { expect(content.first['content'].first['text']).to eq 'kept' }
    end

    context 'embed block is dropped' do
      let(:html) { '<p>text</p><iframe src="http://x"></iframe>' }

      it { expect(content.map { |n| n['type'] }).to eq %w[paragraph] }
    end
  end
end
