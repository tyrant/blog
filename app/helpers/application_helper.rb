module ApplicationHelper

  def first_img_src_for(post)
    first_img = Nokogiri::HTML(post.content_cache).css('img').first
    if !first_img.nil? && !a_bloody_emoji?(first_img)
      img.first['src']
    else
      'https://via.placeholder.com/300'
    end
  end

  # Turns out the emojis of copypasta'd Facebook text are 16x16 <img>s, with
  # alt="[the actual UTF8 emoji character]". We can detect this.
  # Manually going through every single emoji isn't the most elegant detection
  # method, but it'll do for now.
  def a_bloody_emoji?(possibly_emoji_img)
    %w(😂 😁 ❤️ 😞 😬 💫).include? possibly_emoji_img['alt']
  end
end
