require 'rails_helper'

describe ComfyBlogPostMethods do

  let!(:site)   { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:sa)     { create :category, label: 'Shite Advice', site: site }
  let!(:whimsy) { create :category, label: 'Whimsy', site: site }
  let!(:nsfw)   { create :category, label: 'NSFW', site: site }

  describe '#nsfw?' do
    let!(:post) { create :post, site: site, layout: layout }

    context 'posting without an NSFW categorization' do
      it { expect(post.nsfw?).to eq false }
    end

    context 'posting with an NSFW categorization' do
      let!(:cat) { create :categorization, category: nsfw, categorized: post }
      it { expect(post.nsfw?).to eq true }
    end
  end

  describe '#prev_nek' do
    # Six posts; a smattering of categorizations.
    
    let!(:posts) { (0..5).map { |i| create :post,
                                           site: site,
                                           layout: layout,
                                           published_at: DateTime.now + (i-8).days } }

    # Shite Advice: posts 0,2,4
    let!(:sa_posts) { [0, 2, 4].each { |i| create :categorization,
                                                  category: sa,
                                                  categorized: posts[i] } }

    # Whimsy: posts 1,3,5
    let!(:whimsy_posts) { [1, 3, 5].each { |i| create :categorization,
                                                      category: whimsy,
                                                      categorized: posts[i] } }

    # Raunch: middle two. We want to return posts 2, 3 ONLY if nsfw is truthy.
    # Otherwise they should never appear in prev/nek.
    let!(:nsfw_posts) { [2, 3].each { |i| create :categorization,
                                                  category: nsfw,
                                                  categorized: posts[i] } }

    describe 'No category filtering' do
      it { expect(posts[0].prev).to eq nil }
      it { expect(posts[0].nek).to eq posts[1] }

      it { expect(posts[2].prev).to eq posts[1] }
      it { expect(posts[2].nek).to eq posts[4] } # Not 3 - NSFW posts are hidden!

      it { expect(posts[5].prev).to eq posts[4] }
      it { expect(posts[5].nek). to eq nil }
    end

    describe 'Category filtering' do
      describe "filtering just Shite Advice" do
        it { expect(posts[0].prev(category: sa)).to eq nil }
        it { expect(posts[0].nek(category: sa)).to eq posts[4] } # 4, not 2 - 2 is NSFW

        it { expect(posts[1].prev(category: sa)).to eq posts[0] }
        it { expect(posts[1].nek(category: sa)).to eq posts[4] }

        it { expect(posts[2].prev(category: sa)).to eq posts[0] }
        it { expect(posts[2].nek(category: sa)).to eq posts[4] }

        it { expect(posts[3].prev(category: sa)).to eq posts[0] }
        it { expect(posts[3].nek(category: sa)).to eq posts[4] }

        it { expect(posts[4].prev(category: sa)).to eq posts[0] }
        it { expect(posts[4].nek(category: sa)).to eq nil }

        it { expect(posts[5].prev(category: sa)).to eq posts[4] }
        it { expect(posts[5].nek(category: sa)).to eq nil }
      end

      describe "filtering just Whimsy" do
        it { expect(posts[0].prev(category: whimsy)).to eq nil }
        it { expect(posts[0].nek(category: whimsy)).to eq posts[1] }

        it { expect(posts[1].prev(category: whimsy)).to eq nil }
        it { expect(posts[1].nek(category: whimsy)).to eq posts[5] }

        it { expect(posts[2].prev(category: whimsy)).to eq posts[1] }
        it { expect(posts[2].nek(category: whimsy)).to eq posts[5] }

        it { expect(posts[3].prev(category: whimsy)).to eq posts[1] }
        it { expect(posts[3].nek(category: whimsy)).to eq posts[5] }

        it { expect(posts[4].prev(category: whimsy)).to eq posts[1] }
        it { expect(posts[4].nek(category: whimsy)).to eq posts[5] }

        it { expect(posts[5].prev(category: whimsy)).to eq posts[1] }
        it { expect(posts[5].nek(category: whimsy)).to eq nil }
      end

      describe "NSFW filter: naughty posts appear only when whitelisted" do
        describe "querying post2 with nsfw filter absent" do
          it { expect(posts[1].prev(category: sa)).to eq posts[0] }
          it { expect(posts[1].nek(category: sa)).to eq posts[4] }
        end

        describe "querying post2 with nsfw filter manually false" do
          it { expect(posts[1].prev(category: sa, nsfw: false)).to eq posts[0] }
          it { expect(posts[1].nek(category: sa, nsfw: false)).to eq posts[4] }
        end

        describe "querying post2 with nsfw filter manually true" do
          it { expect(posts[1].prev(category: sa, nsfw: true)).to eq posts[0] }
          it { expect(posts[1].nek(category: sa, nsfw: true)).to eq posts[2] }
        end

        describe "querying post2 with category absent and nsfw absent" do
          it { expect(posts[1].prev).to eq posts[0] }
          it { expect(posts[1].nek).to eq posts[4] }
        end

        describe "querying post2 with category absent and nsfw false" do
          it { expect(posts[1].prev(nsfw: false)).to eq posts[0] }
          it { expect(posts[1].nek(nsfw: false)).to eq posts[4] }
        end

        describe "querying post1 with category absent and nsfw true" do
          it { expect(posts[0].prev(nsfw: true)).to eq nil }
          it { expect(posts[0].nek(nsfw: true)).to eq posts[1] }
        end

        describe "querying post2 with category absent and nsfw true" do
          it { expect(posts[1].prev(nsfw: true)).to eq posts[0] }
          it { expect(posts[1].nek(nsfw: true)).to eq posts[2] }
        end

        describe "querying post3 with category absent and nsfw true" do
          it { expect(posts[2].prev(nsfw: true)).to eq posts[1] }
          it { expect(posts[2].nek(nsfw: true)).to eq posts[3] }
        end

        describe "querying post4 with category absent and nsfw true" do
          it { expect(posts[3].prev(nsfw: true)).to eq posts[2] }
          it { expect(posts[3].nek(nsfw: true)).to eq posts[4] }
        end

        describe "querying post5 with category absent and nsfw true" do
          it { expect(posts[4].prev(nsfw: true)).to eq posts[3] }
          it { expect(posts[4].nek(nsfw: true)).to eq posts[5] }
        end

        describe "querying post6 with category absent and nsfw true" do
          it { expect(posts[5].prev(nsfw: true)).to eq posts[4] }
          it { expect(posts[5].nek(nsfw: true)).to eq nil }
        end
      end

      describe "Filtering"
    end
  end

  describe '.active_storage_url?' do
    it 'returns true for ActiveStorage blob URLs' do
      url = 'http://localhost:3000/rails/active_storage/blobs/redirect/xyz123/image.jpg'
      expect(Comfy::Blog::Post.active_storage_url?(url)).to eq true
    end

    it 'returns false for external URLs' do
      url = 'https://example.com/image.jpg'
      expect(Comfy::Blog::Post.active_storage_url?(url)).to eq false
    end

    it 'returns false for relative paths' do
      url = '/images/logo.png'
      expect(Comfy::Blog::Post.active_storage_url?(url)).to eq false
    end
  end

  describe '.a_bloody_emoji?' do
    it 'returns true for emoji images' do
      img = Nokogiri::HTML.fragment('<img alt="😂">').at('img')
      expect(Comfy::Blog::Post.a_bloody_emoji?(img)).to eq true
    end

    it 'returns false for non-emoji images' do
      img = Nokogiri::HTML.fragment('<img alt="A cute cat">').at('img')
      expect(Comfy::Blog::Post.a_bloody_emoji?(img)).to eq false
    end

    it 'returns false for images without alt text' do
      img = Nokogiri::HTML.fragment('<img>').at('img')
      expect(Comfy::Blog::Post.a_bloody_emoji?(img)).to eq false
    end
  end

  describe '.blob_id_from_src' do
    context 'with Rails 6 format URL (Marshal-encoded)' do
      # Rails 6 format: {"_rails":{"message":"BAhpCw==","exp":null,"pur":"blob_id"}}
      # where "BAhpCw==" is Marshal.dump(11) then Base64.encode64
      let(:blob_id) { 11 }
      let(:marshal_encoded) { Base64.strict_encode64(Marshal.dump(blob_id)) }
      let(:message) do
        Base64.urlsafe_encode64({
          _rails: {
            message: marshal_encoded,
            exp: nil,
            pur: 'blob_id'
          }
        }.to_json, padding: false)
      end
      let(:signed_id) { "#{message}--somesignature123" }
      let(:url) { "http://localhost:3000/rails/active_storage/blobs/redirect/#{signed_id}/image.jpg" }

      it 'extracts the blob_id' do
        expect(Comfy::Blog::Post.blob_id_from_src(src: url)).to eq blob_id
      end
    end

    context 'with Rails 8 format URL (direct data)' do
      # Rails 8 format: {"_rails":{"data":1211,"pur":"blob_id"}}
      let(:blob_id) { 1211 }
      let(:message) do
        Base64.urlsafe_encode64({
          _rails: {
            data: blob_id,
            pur: 'blob_id'
          }
        }.to_json, padding: false)
      end
      let(:signed_id) { "#{message}--33788534f951b79669b0b8fb46bb3a00dfacc5c4" }
      let(:url) { "http://localhost:3000/rails/active_storage/blobs/redirect/#{signed_id}/comedian.png" }

      it 'extracts the blob_id' do
        expect(Comfy::Blog::Post.blob_id_from_src(src: url)).to eq blob_id
      end
    end

    context 'with invalid URL format' do
      it 'returns nil and logs warning for malformed signed_id' do
        url = 'http://localhost:3000/rails/active_storage/blobs/redirect/notbase64/image.jpg'
        expect(Rails.logger).to receive(:error)
        expect(Comfy::Blog::Post.blob_id_from_src(src: url)).to be_nil
      end

      it 'returns nil for URLs without signed_id' do
        url = 'http://example.com/image.jpg'
        expect(Rails.logger).to receive(:error)
        expect(Comfy::Blog::Post.blob_id_from_src(src: url)).to be_nil
      end
    end
  end

  describe '#first_img_src' do
    let!(:post) { create :post, site: site, layout: layout, content_cache: nil }

    context 'with no images in content_cache' do
      before { post.update_column(:content_cache, '<p>Just text, no images</p>') }
      
      it 'returns nil' do
        expect(post.first_img_src).to be_nil
      end
    end

    context 'with only emoji images' do
      before do
        post.update_column(:content_cache, '<p><img alt="😂"><img alt="❤️"></p>')
      end
      
      it 'returns nil' do
        expect(post.first_img_src).to be_nil
      end
    end

    context 'with regular images' do
      before do
        post.update_column(:content_cache, '<p><img src="http://example.com/cat.jpg" alt="cat"></p>')
      end
      
      it 'returns the first image src' do
        expect(post.first_img_src).to eq 'http://example.com/cat.jpg'
      end
    end

    context 'with emoji images followed by regular images' do
      before do
        html = '<p><img alt="😂"><img src="http://example.com/real.jpg" alt="photo"></p>'
        post.update_column(:content_cache, html)
      end
      
      it 'skips emojis and returns first non-emoji image' do
        expect(post.first_img_src).to eq 'http://example.com/real.jpg'
      end
    end
  end

  describe '#resized_blob_or_orig_or_placeholder_url' do
    let!(:post) { create :post, site: site, layout: layout, content_cache: nil }

    context 'when post has no images' do
      before { post.update_column(:content_cache, '<p>No images here</p>') }
      
      it 'returns placeholder URL' do
        url = post.resized_blob_or_orig_or_placeholder_url(x: 100, y: 200)
        expect(url).to eq 'http://picsum.photos/100/200'
      end
    end

    context 'when post has external image URL' do
      before do
        post.update_column(:content_cache, '<img src="https://example.com/photo.jpg">')
      end
      
      it 'returns the external URL unchanged' do
        url = post.resized_blob_or_orig_or_placeholder_url
        expect(url).to eq 'https://example.com/photo.jpg'
      end
    end

    context 'when post has ActiveStorage image' do
      let(:blob) { create(:active_storage_blob) }
      let(:signed_id) { blob.signed_id }
      let(:as_url) { "http://localhost:3000/rails/active_storage/blobs/redirect/#{signed_id}/image.jpg" }
      
      before do
        post.update_column(:content_cache, "<img src=\"#{as_url}\">")
      end
      
      it 'returns a variant representation path' do
        url = post.resized_blob_or_orig_or_placeholder_url(x: 512, y: 512)
        expect(url).to match(%r{^/rails/active_storage/representations})
      end
    end

    context 'when ActiveStorage blob cannot be found' do
      let(:invalid_as_url) { 'http://localhost:3000/rails/active_storage/blobs/redirect/invalid/image.jpg' }
      
      before do
        post.update_column(:content_cache, "<img src=\"#{invalid_as_url}\">")
        allow(Comfy::Blog::Post).to receive(:resized_blob_variant_from).and_return(nil)
      end
      
      it 'falls back to placeholder URL' do
        url = post.resized_blob_or_orig_or_placeholder_url(x: 100, y: 100)
        expect(url).to eq 'http://picsum.photos/100/100'
      end
    end
  end

  describe '.resized_blob_variant_from' do
    context 'with valid Rails 8 signed URL' do
      let(:blob) { create(:active_storage_blob) }
      let(:signed_id) { blob.signed_id }
      let(:url) { "http://localhost:3000/rails/active_storage/blobs/redirect/#{signed_id}/image.jpg" }
      
      it 'returns a variant' do
        variant = Comfy::Blog::Post.resized_blob_variant_from(url, x: 100, y: 100)
        expect(variant).to be_present
        expect(variant.blob).to eq blob
      end
    end

    context 'with Rails 6 signed URL (invalid signature in Rails 8)' do
      let(:blob) { create(:active_storage_blob) }
      let(:blob_id) { blob.id }
      let(:marshal_encoded) { Base64.strict_encode64(Marshal.dump(blob_id)) }
      let(:message) do
        Base64.urlsafe_encode64({
          _rails: {
            message: marshal_encoded,
            exp: nil,
            pur: 'blob_id'
          }
        }.to_json, padding: false)
      end
      let(:signed_id) { "#{message}--oldsignature" }
      let(:url) { "http://localhost:3000/rails/active_storage/blobs/redirect/#{signed_id}/image.jpg" }
      
      it 'falls back to blob_id extraction and returns variant' do
        variant = Comfy::Blog::Post.resized_blob_variant_from(url, x: 200, y: 200)
        expect(variant).to be_present
        expect(variant.blob.id).to eq blob_id
      end
    end

    context 'with completely invalid URL' do
      let(:url) { 'http://example.com/not-activestorage/invalid/image.jpg' }
      
      it 'returns nil' do
        expect(Comfy::Blog::Post.resized_blob_variant_from(url, x: 100, y: 100)).to be_nil
      end
    end
  end
end