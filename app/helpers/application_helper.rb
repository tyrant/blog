module ApplicationHelper

  def first_img_src_for(post)
    Nokogiri::HTML(post.content_cache).css('img').first['src']
  end
end
