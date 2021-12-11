module ApplicationHelper


  # We have a post. We would like to generate a resized-to-filled image variant
  # for any ActiveStorage image that may exist inside the post's content, or if
  # none exists, just a nifty placeholder.
  # x/y defaults: 512px.
  def blob_or_placeholder_for(post, x: 512, y: 512)
    blob = _first_active_storage_img_blob_for(post)
    return "http://picsum.photos/#{x}/#{y}" if blob.nil?

    blob.variant(resize_to_fill: [x, y])
  end


  private


  # We have a post. We would like the Blob object, if any, that generated its
  # banner/hero/whatever <img> src.
  # Take a peek at the sample ActiveStorage URL at the bottom of this file. 
  # Much hoop-jumping through ActiveStorage's Github fiddly-bits reveals that 
  # https://github.com/rails/rails/blob/2a32c4b679a7fdc370d2f635c5285e4a4f161390/activestorage/app/controllers/concerns/active_storage/set_blob.rb 
  # uses that big honkin' hash-thing between 'redirect' and 'dad-changing-a-diaper' 
  # to populate params[:signed_id], then pass it to ActiveStorage::Blob#find_signed!. 
  # Let's replicate that. Done.
  def _first_active_storage_img_blob_for(post)
    src = _first_img_src_for(post)
    return nil if src.nil? || !_src_active_storage_url?(src)

    signed_id = src.split('/')[-2]
    ActiveStorage::Blob.find_signed!(signed_id)
  end


  # We have a post. We would like the URL of its first banner/hero/whatever 
  # <img> src. Yoink it.
  def _first_img_src_for(post)
    img = Nokogiri::HTML(post.content_cache).css('img').first
    return nil if img.nil? || _a_bloody_emoji?(img)

    img['src']
  end


  # Turns out the emojis of copypasta'd Facebook text are 16x16 <img>s, with
  # alt="[the actual UTF8 emoji character]". We can detect this.
  # Manually going through every single emoji isn't the most elegant detection
  # method, but it'll do for now.
  def _a_bloody_emoji?(possibly_emoji_img)
    %w(😂 😁 ❤️ 😞 😬 💫).include? possibly_emoji_img['alt']
  end


  # Clunky, but it'll have to do for now.
  def _src_active_storage_url?(url)
    url.include?('rails/active_storage/blobs')
  end

  # Sample URL: 'http://localhost:3000/rails/active_storage/blobs/redirect/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBDdz09IiwiZXhwIjpudWxsLCJwdXIiOiJibG9iX2lkIn19--0b23b9627bd78603f2b482f156ecc052aa618378/Dad-Changing-A-Diaper-1024x683.jpeg'
end
