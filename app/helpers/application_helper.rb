module ApplicationHelper

  def first_img_src_for(post)
    img = Nokogiri::HTML(post.content_cache).css('img')
    if img.length > 0
      img.first['src']
    else
      'https://via.placeholder.com/300'
    end
  end
end
