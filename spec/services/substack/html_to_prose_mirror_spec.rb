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

  describe 'whitespace normalisation' do
    def text_of(html)
      described_class.execute(html: html, image_resolver: resolver)['content']
    end

    it 'trims a trailing newline from a paragraph' do
      expect(text_of("<p>Body text\r\n</p>").first['content'].first['text']).to eq 'Body text'
    end

    it 'trims a trailing newline from a heading' do
      expect(text_of("<h2>Title\r\n</h2>").first['content'].first['text']).to eq 'Title'
    end

    it 'drops a whitespace-only paragraph' do
      expect(text_of("<p>\r\n</p><p>Real.</p>").map { |b| b['content'].first['text'] }).to eq ['Real.']
    end

    it 'collapses internal whitespace runs to single spaces' do
      expect(text_of("<p>a  b\nc</p>").first['content'].first['text']).to eq 'a b c'
    end

    it 'keeps spacing around inline marks while trimming the trailing newline' do
      joined = text_of("<p>a <strong>b</strong> c\r\n</p>").first['content'].map { |n| n['text'] }.join
      expect(joined).to eq 'a b c'
    end

    it 'trims the trailing newline off a caption' do
      caption = text_of("<p><img src='http://x/a.jpg'></p><p class='caption'>Cap.\r\n</p>").first['content'].last
      expect(caption['content'].first['text']).to eq 'Cap.'
    end
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

    describe 'width (imageSize)' do
      def size_of(html)
        described_class.execute(html: html, image_resolver: resolver)['content'].first['content'].first['attrs']['imageSize']
      end

      it { expect(size_of('<p><img src="http://x/a.jpg"></p>')).to eq 'normal' }
      it { expect(size_of('<p><img src="http://x/a.jpg" class="img-full"></p>')).to eq 'full' }
      it { expect(size_of('<p><img src="http://x/a.jpg" class="img-large"></p>')).to eq 'large' }
      it { expect(size_of('<p><img src="http://x/a.jpg" class="foo img-wide bar"></p>')).to eq 'wide' }
    end

    context 'an image nested inside a heading' do
      let(:html) { '<h2><img src="http://x.com/a.jpg" alt="pic"><br></h2>' }

      it 'is pulled out as a captionedImage instead of being dropped' do
        expect(content.map { |b| b['type'] }).to eq(['captionedImage'])
      end

      it { expect(content.first['content'].first['attrs']['src']).to eq 'cdn:http://x.com/a.jpg' }
    end

    context 'a heading with both text and an image' do
      let(:html) { '<h2>Title <img src="http://x.com/a.jpg"></h2>' }

      it 'keeps the heading and adds the image after it' do
        expect(content.map { |b| b['type'] }).to eq(%w[heading captionedImage])
      end
    end
  end

  describe 'youtube embeds' do
    let(:node) { content.first }

    context 'an iframe embed' do
      let(:html) { '<iframe src="https://www.youtube.com/embed/To_RJ_mPNqM"></iframe>' }

      it { expect(node['type']).to eq 'youtube2' }
      it { expect(node['attrs']['videoId']).to eq 'To_RJ_mPNqM' }
      it { expect(node['attrs']).to eq('videoId' => 'To_RJ_mPNqM', 'startTime' => nil, 'endTime' => nil) }
    end

    context 'an iframe nested in a figure' do
      let(:html) { '<figure><iframe src="https://youtu.be/l894JJu5aKY"></iframe></figure>' }

      it { expect(node['type']).to eq 'youtube2' }
      it { expect(node['attrs']['videoId']).to eq 'l894JJu5aKY' }
    end

    context 'a bare watch URL alone in a paragraph' do
      let(:html) { '<p>https://www.youtube.com/watch?v=To_RJ_mPNqM</p>' }

      it { expect(node['type']).to eq 'youtube2' }
      it { expect(node['attrs']['videoId']).to eq 'To_RJ_mPNqM' }
    end

    context 'a link-only paragraph' do
      let(:html) { '<p><a href="https://youtu.be/To_RJ_mPNqM">https://youtu.be/To_RJ_mPNqM</a></p>' }

      it { expect(node['type']).to eq 'youtube2' }
    end

    context 'a start time in the URL' do
      let(:html) { '<p>https://www.youtube.com/watch?v=To_RJ_mPNqM&t=90</p>' }

      it { expect(node['attrs']['startTime']).to eq 90 }
    end

    context 'a youtube link inline with other text' do
      let(:html) { '<p>Watch this: <a href="https://youtu.be/To_RJ_mPNqM">the clip</a> now</p>' }

      it 'stays a paragraph with a link, not a player' do
        expect(node['type']).to eq 'paragraph'
      end
    end

    context 'a non-youtube iframe' do
      let(:html) { '<iframe src="https://example.com/thing"></iframe>' }

      it { expect(content).to be_empty }
    end
  end

  describe 'image captions (opt-in via class="caption")' do
    context 'a class-marked paragraph directly after an image' do
      let(:html) { '<p><img src="http://x.com/a.jpg"></p><p class="caption">The <em>caption</em>.</p>' }

      it 'folds it into the image, leaving no stray paragraph' do
        expect(content.map { |b| b['type'] }).to eq(['captionedImage'])
      end

      it 'the captionedImage carries an image2 then a caption' do
        expect(content.first['content'].map { |c| c['type'] }).to eq(%w[image2 caption])
      end

      it 'the caption keeps the paragraph inline content' do
        caption = content.first['content'].last
        expect(caption['content'].map { |n| n['text'] }.join).to eq 'The caption.'
      end
    end

    context 'an unmarked paragraph after an image' do
      let(:html) { '<p><img src="http://x.com/a.jpg"></p><p>Just body text.</p>' }

      it 'stays body text, not a caption' do
        expect(content.map { |b| b['type'] }).to eq(%w[captionedImage paragraph])
      end

      it 'leaves no caption on the image' do
        expect(content.first['content'].map { |c| c['type'] }).to eq(['image2'])
      end
    end

    context 'a caption paragraph followed by a body paragraph' do
      let(:html) { '<p><img src="http://x.com/a.jpg"></p><p class="caption">Cap.</p><p>Body.</p>' }

      it 'captions with only the marked one' do
        expect(content.map { |b| b['type'] }).to eq(%w[captionedImage paragraph])
      end
    end

    context 'a class-marked paragraph not after an image' do
      let(:html) { '<p>Body.</p><p class="caption">Orphan.</p>' }

      it 'stays a plain paragraph with no stray marker' do
        expect(content.last).to eq('type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Orphan.' }])
      end
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
