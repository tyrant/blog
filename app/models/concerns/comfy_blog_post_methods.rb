module ComfyBlogPostMethods
  extend ActiveSupport::Concern

  included do

    # A note on SELECT NULL: this could just as easily be SELECT *. The exact
    # choice of columns doesn't matter: the point is to verify that the SELECT 
    # sub-query returns zero rows, i.e. NOT EXISTS. 
    scope :nsfw_banished!, -> {
      joins(:categorizations)
        .where("comfy_cms_categorizations.categorized_type = 'Comfy::Blog::Post'")
        .where("NOT EXISTS(
          SELECT NULL FROM comfy_cms_categorizations
            WHERE 
              comfy_cms_categorizations.categorized_id = comfy_blog_posts.id
              AND 
              comfy_cms_categorizations.category_id = (
                SELECT id FROM comfy_cms_categories WHERE label = 'NSFW'
              )
          )")
    }
    
    scope :nsfw_banished, -> (banish) { banish ? nsfw_banished! : where('1=1') }
    
    def nsfw?
      categories.any? &:nsfw?
    end

    # We would like the immediate prev/nek posts straddling this post, ordered
    # by published_at:
    #   self.prev: post_preceding_self
    #   self.nek: post_following_self
    # Preceding/following posts may first be filtered by category.
    # We also have a NSFW filter boolean flag doohickey. This requires special
    # treatment. Yes, NSFW is a category too, but NSFW must be explicitly
    # opt-in: regular filtering ain't good enough.

    def prev(category: nil, nsfw: false)
      Comfy::Blog::Post.where('published_at < ?', self.published_at)
        .published
        .for_category(category&.label)
        .nsfw_banished(!nsfw)
        .order(published_at: :desc)
        .limit(1)
        .first
    end

    def nek(category: nil, nsfw: false)
      Comfy::Blog::Post.where('published_at > ?', self.published_at)
        .published
        .for_category(category&.label)
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
      src = first_img_src
      return "http://picsum.photos/#{x}/#{y}" if src.nil?
      return src unless active_storage_url?(src)

      resized_blob_variant_from(src, x: x, y: y)
    end

    # We would like the Blob object, if any, that generated this post's banner/
    # hero/whatever <img> src:
    # Take a peek at the sample ActiveStorage URL at the bottom of this file. Much
    # hoop-jumping through ActiveStorage's Github fiddly-bits reveals that 
    # https://github.com/rails/rails/blob/2a32c4b679a7fdc370d2f635c5285e4a4f161390/activestorage/app/controllers/concerns/active_storage/set_blob.rb 
    # uses that big honkin' hash-thing between 'redirect' and
    # 'dad-changing-a-diaper' to populate params[:signed_id], then pass it to 
    # ActiveStorage::Blob#find_signed!. Let's replicate that. Done.
    def resized_blob_variant_from(src, x:, y:)
      signed_id = src.split('/')[-2]
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      blob.variant(resize_to_fill: [x, y])
    end

    # We would like the URL of this post's content's first banner/hero/whatever 
    # <img> src that isn't of a bloody emoji. Yoink it.
    def first_img_src
      non_emojis = Nokogiri::HTML(self.content_cache).css('img').reject do |img|
        a_bloody_emoji?(img)
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
    def a_bloody_emoji?(possibly_emoji_img)
      %w(😂 😁 ❤️ 😞 😬 💫).include? possibly_emoji_img['alt']
    end

    # Clunky, but it'll have to do for now.
    def active_storage_url?(url)
      url.include?('rails/active_storage/blobs')
    end

    # Sample URL: 'http://localhost:3000/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDdz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--0b23b9627bd78603f2b482f156ecc052aa618378/Dad-Changing-A-Diaper-1024x683.jpeg'
  end
end
