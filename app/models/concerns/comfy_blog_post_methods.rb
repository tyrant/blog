module ComfyBlogPostMethods
  extend ActiveSupport::Concern

  included do

    # Filters posts by tag name(s), mirroring WithCategories#for_category — used
    # for the public ?category= listing and prev/nek nav, now tag-backed.
    scope :for_tag, ->(*names) {
      if (names = [names].flatten.compact).present?
        distinct.joins(:tags).where("tags.name" => names)
      end
    }

    # A note on SELECT NULL: this could just as easily be SELECT *. The exact
    # choice of columns doesn't matter: the point is to verify that the SELECT
    # sub-query returns zero rows, i.e. NOT EXISTS.
    scope :nsfw_banished!, -> {
      where("NOT EXISTS(
        SELECT NULL FROM blog_post_tags
          JOIN tags ON tags.id = blog_post_tags.tag_id
          WHERE
            blog_post_tags.comfy_blog_post_id = comfy_blog_posts.id
          AND
            tags.name = 'NSFW'
        )")
    }

    scope :nsfw_banished, -> (banish) { banish ? nsfw_banished! : where('1=1') }

    def nsfw?
      tags.exists?(name: 'NSFW')
    end

    # We would like the immediate prev/nek posts straddling this post, ordered
    # by published_at:
    #   self.prev: post_preceding_self
    #   self.nek: post_following_self
    # Preceding/following posts may first be filtered by category.
    # We also have a NSFW filter boolean flag doohickey. This requires special
    # treatment. Yes, NSFW is a category too, but NSFW must be explicitly
    # opt-in: regular filtering ain't good enough.

    def prev(tag: nil, nsfw: false)
      site.blog_posts.where('published_at < ?', self.published_at)
        .published
        .for_tag(tag&.name)
        .nsfw_banished(!nsfw)
        .order(published_at: :desc)
        .limit(1)
        .first
    end

    def nek(tag: nil, nsfw: false)
      site.blog_posts.where('published_at > ?', self.published_at)
        .published
        .for_tag(tag&.name)
        .nsfw_banished(!nsfw)
        .order(published_at: :asc)
        .limit(1)
        .first
    end

    # We would like to generate a resized-to-filled image variant for any 
    # ActiveStorage image that may exist inside this post's content.
    # If, however, there's an image but it's an external and complete URL, just
    # use that. But if there's no image at all, just use a nifty placeholder.
    def resized_blob_or_orig_or_placeholder_url(x: 512, y: 512)
      placeholder_url = "http://picsum.photos/#{x}/#{y}"

      src = first_img_src
      return placeholder_url if src.nil?
      return src unless Comfy::Blog::Post.active_storage_url?(src)

      resized = Comfy::Blog::Post.resized_blob_variant_from(src, x: x, y: y)
      return placeholder_url if resized.blank?

      Rails.application.routes.url_helpers.rails_representation_path(resized, only_path: true)
    end

    # We would like the Blob object, if any, that generated this post's banner/
    # hero/whatever <img> src:
    # Take a peek at the sample ActiveStorage URL at the bottom of this file. Much
    # hoop-jumping through ActiveStorage's Github fiddly-bits reveals that 
    # https://github.com/rails/rails/blob/2a32c4b679a7fdc370d2f635c5285e4a4f161390/activestorage/app/controllers/concerns/active_storage/set_blob.rb 
    # uses that big honkin' hash-thing between 'redirect' and
    # 'dad-changing-a-diaper' to populate params[:signed_id], then pass it to 
    # ActiveStorage::Blob#find_signed!. Let's replicate that. Done.
    def self.resized_blob_variant_from(src, x:, y:)
      signed_id = src.split('/')[-2]
      #blob = ActiveStorage::Blob.find_signed!(signed_id)
      # Try normal signature verification first (for new Rails 8 URLs)
      blob = begin
        ActiveStorage::Blob.find_signed!(signed_id)

      # Fallback for URLs generated before Rails 8 upgrade:
      rescue ActiveSupport::MessageVerifier::InvalidSignature => e
        blob_id = self.blob_id_from_src(src: src)
        return nil if blob_id.nil?
        
        begin
          ActiveStorage::Blob.find(blob_id)
        rescue ActiveRecord::RecordNotFound
          Rails.logger.warn "ActiveStorage::Blob not found for id: #{blob_id}"
          return nil
        end
      end
      
      return nil unless blob
      blob.variant(resize_to_fill: [x, y])
    end

    # We would like the URL of this post's content's first banner/hero/whatever 
    # <img> src that isn't of a bloody emoji. Yoink it.
    def first_img_src
      non_emojis = Nokogiri::HTML(self.content_cache).css('img').reject do |img|
        Comfy::Blog::Post.a_bloody_emoji?(img)
      end

      if non_emojis.length == 0
        nil
      else
        non_emojis.first['src']
      end
    end

    # Turns out the emojis of copypasta'd Facebook text are 16x16 <img>s, with
    # alt="[the actual UTF8 emoji character]". We can detect this.
    # Manually going through every single emoji isn't the most elegant detection
    # method, but it'll do for now.
    def self.a_bloody_emoji?(possibly_emoji_img)
      %w(😂 😁 ❤️ 😞 😬 💫).include? possibly_emoji_img['alt']
    end

    # Clunky, but it'll have to do for now.
    def self.active_storage_url?(url)
      url.include?('rails/active_storage/blobs')
    end


    # Extracts the Blob ID from a Rails 6 or Rails 8 signed ActiveStorage <img> URL.
    # Signed format: "BASE64_MESSAGE--SIGNATURE"
    def self.blob_id_from_src(src:)
      signed_id = src.split('/')[-2]
      message = signed_id.split('--').first
      decoded = JSON.parse(Base64.urlsafe_decode64(message))
      
      # Rails 8 format: data is directly in the JSON
      if decoded.dig('_rails', 'data')
        decoded.dig('_rails', 'data')
      # Rails 6 format: data is Marshal-encoded in the 'message' field
      elsif decoded.dig('_rails', 'message')
        marshal_encoded = decoded.dig('_rails', 'message')
        Marshal.load(Base64.decode64(marshal_encoded))
      else
        Rails.logger.warn "Could not extract blob_id from signed_id: #{signed_id}"
        nil
      end
    rescue => e
      Rails.logger.error "Failed to extract blob_id from src #{src}: #{e.message}"
      nil
    end

    # Sample Rails 6 URL: 'http://localhost:3000/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDdz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--0b23b9627bd78603f2b482f156ecc052aa618378/Dad-Changing-A-Diaper-1024x683.jpeg'
    # 
    # Sample Rails 8 URL: 'http://localhost:3000/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsiZGF0YSI6MTIxMSwicHVyIjoiYmxvYl9pZCJ9fQ==--33788534f951b79669b0b8fb46bb3a00dfacc5c4/comedian_7688199.png'
  end
end
