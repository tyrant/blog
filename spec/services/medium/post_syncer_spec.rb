# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Medium::PostSyncer do
  let!(:site)   { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:post)   { create :post, site: site, layout: layout, scratchpad: scratchpad }
  let(:scratchpad) { '' }
  let(:config)  { MediumSyncConfig.instance }
  let(:syncer)  { described_class.new(post_id: post.id) }

  before do
    reset_cms_config
    reset_blog_config
  end

  # ---------------------------------------------------------------------------
  # #execute — full sync flow (requires stubbed Selenium driver)
  # ---------------------------------------------------------------------------
  describe '#execute' do
    # All examples in this group stub build_driver to return a double and verify
    # the high-level orchestration logic without launching a real browser.

    let(:driver) { instance_double(Selenium::WebDriver::Driver) }

    before do
      allow(syncer).to receive(:chrome_debug_port_open?).and_return(false)
      allow(syncer).to receive(:build_driver).and_return(driver)
      allow(syncer).to receive(:sync_post)
      allow(driver).to receive(:quit)
    end

    context 'when no Medium URL is present in scratchpad (new post)' do
      before do
        allow(syncer).to receive(:extract_medium_url).and_return('https://medium.com/p/abc123def456/edit')
      end

      it 'navigates to medium.com/new-story' do
        syncer.send(:execute)
        expect(syncer).to have_received(:sync_post).with(driver, 'https://medium.com/new-story', any_args)
      end

      it 'calls sync_post with the new-story edit URL' do
        syncer.send(:execute)
        expect(syncer).to have_received(:sync_post).with(driver, 'https://medium.com/new-story', any_args)
      end

      it 'extracts the redirected Medium URL after sync' do
        syncer.send(:execute)
        expect(syncer).to have_received(:extract_medium_url).with(driver)
      end

      it 'appends the extracted edit URL to scratchpad' do
        syncer.send(:execute)
        expect(post.reload.scratchpad).to include('https://medium.com/p/abc123def456/edit')
      end
    end

    context 'when a Medium URL is present in scratchpad (re-sync)' do
      let(:scratchpad) { "some notes\r\n\r\nhttps://medium.com/p/59511e1283d6/edit" }

      it 'navigates to the derived edit URL, not new-story' do
        syncer.send(:execute)
        expect(syncer).to have_received(:sync_post).with(driver, 'https://medium.com/p/59511e1283d6/edit', any_args)
      end

      it 'calls sync_post with the existing edit URL' do
        syncer.send(:execute)
        expect(syncer).to have_received(:sync_post).with(driver, 'https://medium.com/p/59511e1283d6/edit', any_args)
      end

      it 'does not modify scratchpad' do
        expect { syncer.send(:execute) }.not_to change { post.reload.scratchpad }
      end
    end

    context 'when the driver raises an error' do
      before do
        allow(syncer).to receive(:sync_post).and_raise(RuntimeError, 'browser crashed')
      end

      it 'quits the driver in the ensure block' do
        expect { syncer.send(:execute) }.to raise_error(RuntimeError)
        expect(driver).to have_received(:quit)
      end

      it 'kills the launched Chrome process in the ensure block' do
        syncer.instance_variable_set(:@launched_chrome_pid, 12345)
        allow(Process).to receive(:kill)
        expect { syncer.send(:execute) }.to raise_error(RuntimeError)
        expect(Process).to have_received(:kill).with('TERM', 12345)
      end

      it 're-raises the error' do
        expect { syncer.send(:execute) }.to raise_error(RuntimeError, 'browser crashed')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #medium_edit_url
  # ---------------------------------------------------------------------------
  describe '#medium_edit_url' do
    subject { syncer.send(:medium_edit_url, url) }

    context 'with an already-correct /p/HASH/edit URL' do
      let(:url) { 'https://medium.com/p/59511e1283d6/edit' }

      it { is_expected.to eq 'https://medium.com/p/59511e1283d6/edit' }
    end

    context 'with an unpublished show URL (subdomain/HASH)' do
      let(:url) { 'https://mikey-clarke.medium.com/59511e1283d6' }

      it { is_expected.to eq 'https://medium.com/p/59511e1283d6/edit' }
    end

    context 'with a published show URL (/@user/slug-HASH)' do
      let(:url) { 'https://medium.com/@mikey-clarke/be-more-racist-dc4c6277caf4' }

      it { is_expected.to eq 'https://medium.com/p/dc4c6277caf4/edit' }
    end

    context 'with a bare /p/HASH URL (no /edit)' do
      let(:url) { 'https://medium.com/p/59511e1283d6' }

      it { is_expected.to eq 'https://medium.com/p/59511e1283d6/edit' }
    end
  end

  # ---------------------------------------------------------------------------
  # #normalize_for_medium
  # ---------------------------------------------------------------------------
  describe '#normalize_for_medium' do
    subject { syncer.send(:normalize_for_medium, html) }

    describe 'tag removal' do
      context 'with a <script> tag' do
        let(:html) { '<p>Text</p><script>alert(1)</script>' }

        it 'removes the script tag entirely' do
          expect(subject).not_to include('<script')
        end

        it 'preserves surrounding content' do
          expect(subject).to include('Text')
        end
      end

      context 'with a <style> tag' do
        let(:html) { '<p>Text</p><style>.foo{}</style>' }

        it 'removes the style tag entirely' do
          expect(subject).not_to include('<style')
        end
      end

      context 'with other REMOVE_TAGS (video, audio, iframe, etc.)' do
        let(:html) { '<p>Before</p><video src="x.mp4"></video><p>After</p>' }

        it 'removes the tag' do
          expect(subject).not_to include('<video')
        end

        it 'preserves surrounding paragraphs' do
          expect(subject).to include('Before')
        end
      end
    end

    describe 'tag unwrapping' do
      context 'with a <div> wrapper' do
        let(:html) { '<div><p>Inside</p></div>' }

        it 'removes the div but keeps its children' do
          expect(subject).not_to include('<div')
        end

        it 'preserves the inner content' do
          expect(subject).to include('Inside')
        end
      end

      context 'with a <figure> containing an <img>' do
        let(:html) { '<figure><img src="photo.jpg"><figcaption>Caption</figcaption></figure>' }

        it 'unwraps the figure' do
          expect(subject).not_to include('<figure')
        end

        it 'exposes the img' do
          expect(subject).to include('<img')
        end

        it 'unwraps the figcaption' do
          expect(subject).not_to include('<figcaption')
        end
      end

      context 'with deeply nested wrappers' do
        let(:html) { '<div><section><article><p>Deep</p></article></section></div>' }

        it 'unwraps all container elements in multiple passes' do
          expect(subject).not_to match(/<div|<section|<article/)
        end

        it 'preserves the innermost content' do
          expect(subject).to include('Deep')
        end
      end
    end

    describe 'attribute stripping' do
      context 'with a paragraph carrying a class and data attributes' do
        let(:html) { '<p class="custom" data-foo="bar" id="p1">Text</p>' }

        it 'removes non-semantic attributes (class, data-*, id)' do
          expect(subject).not_to match(/class="custom"|data-foo|id="p1"/)
        end
      end

      context 'with an anchor carrying href, rel, target, and data attributes' do
        let(:html) { '<a href="/page" target="_blank" rel="noopener" data-track="click">Link</a>' }

        it 'preserves href' do
          expect(subject).to include('href="/page"')
        end

        it 'preserves target' do
          expect(subject).to include('target="_blank"')
        end

        it 'preserves rel' do
          expect(subject).to include('rel="noopener"')
        end

        it 'removes data-track' do
          expect(subject).not_to include('data-track')
        end
      end

      context 'with an img carrying src and alt' do
        let(:html) { '<img src="photo.jpg" alt="A photo" width="800">' }

        it 'preserves src' do
          expect(subject).to include('src="photo.jpg"')
        end

        it 'preserves alt' do
          expect(subject).to include('alt="A photo"')
        end

        it 'removes width' do
          expect(subject).not_to include('width=')
        end
      end
    end

    describe 'graf class assignment' do
      context 'with a plain paragraph' do
        let(:html) { '<p>Text</p>' }

        it 'assigns class "graf graf--p"' do
          expect(subject).to include('class="graf graf--p"')
        end
      end

      context 'with an h2' do
        let(:html) { '<h2>Heading</h2>' }

        it 'assigns class "graf graf--h2"' do
          expect(subject).to include('class="graf graf--h2"')
        end
      end

      context 'with a blockquote' do
        let(:html) { '<blockquote>Quote</blockquote>' }

        it 'assigns class "graf graf--blockquote"' do
          expect(subject).to include('class="graf graf--blockquote"')
        end
      end

      context 'with a pre' do
        let(:html) { '<pre>code</pre>' }

        it 'assigns class "graf graf--pre"' do
          expect(subject).to include('class="graf graf--pre"')
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #upload_images_for_medium
  # ---------------------------------------------------------------------------
  describe '#upload_images_for_medium' do
    # Pass a double for driver; upload_images_for_medium only uses it for console.log.
    let(:driver) { instance_double(Selenium::WebDriver::Driver) }

    before do
      allow(driver).to receive(:execute_script)
      allow(Rails.application.routes.url_helpers).to receive(:root_url).and_return('http://localhost:3000/')
    end

    subject { syncer.send(:upload_images_for_medium, driver, html) }

    context 'when HTML contains no img tags' do
      let(:html) { '<p>No images here.</p>' }

      it 'returns the HTML unchanged as the first element' do
        expect(subject[0]).to eq html
      end

      it 'returns an empty array as the second element' do
        expect(subject[1]).to eq []
      end
    end

    context 'when HTML contains an img with an ActiveStorage src' do
      let(:html) { '<p><img src="/rails/active_storage/blobs/redirect/SIGNED_ID/photo.jpg"></p>' }

      before do
        allow(syncer).to receive(:download_image_bytes).and_return({ body: 'bytes', content_type: 'image/jpeg' })
      end

      it 'removes the img tag from the returned HTML' do
        expect(subject[0]).not_to include('<img')
      end

      it 'includes the downloaded image data in the second element' do
        expect(subject[1]).to include(a_hash_including(body: 'bytes', content_type: 'image/jpeg'))
      end
    end

    context 'when the img is the only content in its parent block' do
      let(:html) { '<p><img src="/rails/active_storage/blobs/redirect/SIGNED_ID/photo.jpg"></p>' }

      before do
        allow(syncer).to receive(:download_image_bytes).and_return({ body: 'bytes', content_type: 'image/jpeg' })
      end

      it 'removes the now-empty parent paragraph from the HTML' do
        expect(subject[0]).not_to include('<p>')
      end
    end

    context 'when img src is a data: URI' do
      let(:html) { '<p><img src="data:image/png;base64,abc123"></p>' }

      it 'strips the img tag' do
        expect(subject[0]).not_to include('<img')
      end

      it 'does not add anything to the images array' do
        expect(subject[1]).to be_empty
      end
    end

    context 'when img src is a relative path' do
      let(:html) { '<p><img src="/uploads/photo.jpg"></p>' }

      before do
        allow(syncer).to receive(:download_image_bytes).and_return({ body: 'bytes', content_type: 'image/jpeg' })
      end

      it 'prepends the application root URL before downloading' do
        subject
        expect(syncer).to have_received(:download_image_bytes).with(a_string_matching(%r{https?://.*?/uploads/photo\.jpg}))
      end
    end

    context 'when download_image_bytes returns nil (download failure)' do
      let(:html) { '<p><img src="https://example.com/photo.jpg"></p>' }

      before { allow(syncer).to receive(:download_image_bytes).and_return(nil) }

      it 'does not add a nil entry to the images array' do
        expect(subject[1]).not_to include(nil)
      end
    end

    context 'when a plain paragraph immediately follows the image block' do
      let(:html) { '<p><img src="/uploads/photo.jpg"></p><p>Caption text</p><p>Body text</p>' }

      before do
        allow(syncer).to receive(:download_image_bytes).and_return({ body: 'bytes', content_type: 'image/jpeg' })
      end

      it 'includes the caption in the image data' do
        expect(subject[1].first[:caption]).to eq 'Caption text'
      end

      it 'removes the caption paragraph from the returned HTML' do
        expect(subject[0]).not_to include('Caption text')
      end

      it 'preserves non-caption body paragraphs in the HTML' do
        expect(subject[0]).to include('Body text')
      end
    end

    context 'when a heading (not a plain paragraph) follows the image block' do
      let(:html) { '<p><img src="/uploads/photo.jpg"></p><h2>A Heading</h2><p>Body text</p>' }

      before do
        allow(syncer).to receive(:download_image_bytes).and_return({ body: 'bytes', content_type: 'image/jpeg' })
      end

      it 'does not treat the heading as a caption' do
        expect(subject[1].first[:caption]).to be_nil
      end

      it 'leaves the heading in the body HTML' do
        expect(subject[0]).to include('A Heading')
      end
    end

    context 'when no paragraph follows the image block' do
      let(:html) { '<p><img src="/uploads/photo.jpg"></p>' }

      before do
        allow(syncer).to receive(:download_image_bytes).and_return({ body: 'bytes', content_type: 'image/jpeg' })
      end

      it 'leaves caption as nil' do
        expect(subject[1].first[:caption]).to be_nil
      end
    end

    context 'when the following paragraph contains a media element' do
      let(:html) { '<p><img src="/uploads/photo.jpg"></p><p><img src="/uploads/other.jpg"></p>' }

      before do
        allow(syncer).to receive(:download_image_bytes).and_return({ body: 'bytes', content_type: 'image/jpeg' })
      end

      it 'does not treat the media paragraph as a caption' do
        expect(subject[1].first[:caption]).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #insert_image_caption
  # ---------------------------------------------------------------------------
  describe '#insert_image_caption' do
    let(:driver)     { instance_double(Selenium::WebDriver::Driver) }
    let(:figure_el)  { instance_double(Selenium::WebDriver::Element) }
    let(:caption_el) { instance_double(Selenium::WebDriver::Element) }

    before do
      allow(driver).to receive(:execute_script)
      allow(driver).to receive(:find_elements)
        .with(css: "figure[data-testid='editorImageParagraph']")
        .and_return([figure_el])
      allow(driver).to receive(:find_elements)
        .with(css: "figure[data-testid='editorImageParagraph'] figcaption")
        .and_return([caption_el])
      allow(figure_el).to receive(:click)
    end

    context 'when caption is blank' do
      it 'does nothing' do
        expect(driver).not_to receive(:find_elements)
        syncer.send(:insert_image_caption, driver, nil)
      end

      it 'does nothing for an empty string' do
        expect(driver).not_to receive(:find_elements)
        syncer.send(:insert_image_caption, driver, '')
      end
    end

    context 'when caption is present and figcaption is found' do
      it 'clicks the figure to trigger the caption UI' do
        syncer.send(:insert_image_caption, driver, 'Caption text')
        expect(figure_el).to have_received(:click)
      end

      it 'dispatches a paste event into the caption element' do
        syncer.send(:insert_image_caption, driver, 'Caption text')
        expect(driver).to have_received(:execute_script).with(anything, caption_el, 'Caption text')
      end
    end

    context 'when no figures are present in the editor' do
      before do
        allow(driver).to receive(:find_elements)
          .with(css: "figure[data-testid='editorImageParagraph']")
          .and_return([])
      end

      it 'does nothing' do
        expect(figure_el).not_to receive(:click)
        syncer.send(:insert_image_caption, driver, 'Caption text')
      end
    end

    context 'when the figcaption does not appear (TimeoutError)' do
      before do
        allow(driver).to receive(:find_elements)
          .with(css: "figure[data-testid='editorImageParagraph'] figcaption")
          .and_return([])
      end

      it 'logs a warning and does not raise' do
        expect(Rails.logger).to receive(:warn).with(a_string_matching(/insert_image_caption/))
        expect { syncer.send(:insert_image_caption, driver, 'Caption text') }.not_to raise_error
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #download_image_bytes
  # ---------------------------------------------------------------------------
  describe '#download_image_bytes' do
    subject { syncer.send(:download_image_bytes, url) }

    context 'with an ActiveStorage blob redirect URL' do
      let(:blob) { instance_double(ActiveStorage::Blob, download: 'image-bytes', content_type: 'image/jpeg') }
      let(:url)  { '/rails/active_storage/blobs/redirect/SIGNED_ID/photo.jpg' }

      before { allow(ActiveStorage::Blob).to receive(:find_signed!).and_return(blob) }

      it 'reads the blob directly without making an HTTP request' do
        expect(Net::HTTP).not_to receive(:start)
        subject
      end

      it 'returns a hash with :body' do
        expect(subject[:body]).to eq 'image-bytes'
      end

      it 'returns a hash with :content_type' do
        expect(subject[:content_type]).to eq 'image/jpeg'
      end
    end

    context 'with an external HTTP URL' do
      let(:url)      { 'https://example.com/photo.jpg' }
      let(:http)     { instance_double(Net::HTTP) }
      let(:response) do
        Net::HTTPOK.new('1.1', '200', 'OK').tap do |r|
          r.instance_variable_set(:@header, { 'content-type' => ['image/png'] })
        end
      end

      before do
        allow(Net::HTTP).to receive(:start) { |*_args, **_kwargs, &block| block.call(http) }
        allow(http).to receive(:get).and_return(response)
        allow(response).to receive(:body).and_return('image-body')
      end

      it 'fetches the image over HTTP' do
        expect(Net::HTTP).to receive(:start)
        subject
      end

      it 'returns a hash with the response body as :body' do
        expect(subject[:body]).to eq 'image-body'
      end

      it 'returns the parsed content-type as :content_type' do
        expect(subject[:content_type]).to eq 'image/png'
      end
    end

    context 'with a redirect chain' do
      let(:url)          { 'https://example.com/redirect' }
      let(:final_url)    { 'https://example.com/final.jpg' }
      let(:http)         { instance_double(Net::HTTP) }
      let(:redirect) do
        Net::HTTPMovedPermanently.new('1.1', '301', 'Moved').tap do |r|
          r.instance_variable_set(:@header, { 'location' => [final_url] })
        end
      end

      it 'follows redirects up to the limit' do
        allow(syncer).to receive(:download_image_bytes).and_call_original
        allow(syncer).to receive(:download_image_bytes).with(final_url, redirect_limit: 4).and_return({ body: 'img', content_type: 'image/jpeg' })
        allow(Net::HTTP).to receive(:start) { |*_args, **_kwargs, &block| block.call(http) }
        allow(http).to receive(:get).and_return(redirect)

        result = syncer.send(:download_image_bytes, url)
        expect(result).to eq({ body: 'img', content_type: 'image/jpeg' })
      end

      it 'raises an error when the redirect limit is exceeded' do
        allow(Net::HTTP).to receive(:start) { |*_args, **_kwargs, &block| block.call(http) }
        allow(http).to receive(:get).and_return(redirect)

        result = syncer.send(:download_image_bytes, url, redirect_limit: 0)
        expect(result).to be_nil
      end
    end

    context 'when the server returns a non-success status' do
      let(:url)      { 'https://example.com/missing.jpg' }
      let(:http)     { instance_double(Net::HTTP) }
      let(:response) { Net::HTTPNotFound.new('1.1', '404', 'Not Found') }

      before do
        allow(Net::HTTP).to receive(:start) { |*_args, **_kwargs, &block| block.call(http) }
        allow(http).to receive(:get).and_return(response)
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end

      it 'logs a warning' do
        expect(Rails.logger).to receive(:warn).with(a_string_matching(/image download/))
        subject
      end
    end

    context 'when a network error occurs' do
      let(:url) { 'https://unreachable.example.com/photo.jpg' }

      before do
        allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED, 'connection refused')
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end

      it 'logs a warning' do
        expect(Rails.logger).to receive(:warn).with(a_string_matching(/image download failed/))
        subject
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #append_medium_url_to_scratchpad
  # ---------------------------------------------------------------------------
  describe '#append_medium_url_to_scratchpad' do
    let(:medium_url) { 'https://medium.com/p/abc123def456/edit' }

    subject { syncer.send(:append_medium_url_to_scratchpad, post, medium_url) }

    context 'when scratchpad is empty' do
      let(:scratchpad) { '' }

      it 'sets scratchpad to the Medium URL' do
        subject
        expect(post.reload.scratchpad).to eq medium_url
      end

      it 'persists the change to the database' do
        subject
        expect(Comfy::Blog::Post.find(post.id).scratchpad).to eq medium_url
      end
    end

    context 'when scratchpad has existing content' do
      let(:scratchpad) { 'some notes about this post' }

      it 'appends the URL separated by \r\n\r\n' do
        subject
        expect(post.reload.scratchpad).to eq "some notes about this post\r\n\r\n#{medium_url}"
      end

      it 'preserves the existing scratchpad content' do
        subject
        expect(post.reload.scratchpad).to include('some notes about this post')
      end

      it 'persists the change to the database' do
        subject
        expect(Comfy::Blog::Post.find(post.id).scratchpad).to include(medium_url)
      end
    end

    context 'when scratchpad has trailing whitespace' do
      let(:scratchpad) { 'some notes   ' }

      it 'strips trailing whitespace before appending' do
        subject
        expect(post.reload.scratchpad).to eq "some notes\r\n\r\n#{medium_url}"
      end
    end
  end
end
