# frozen_string_literal: true

xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "Bourgeois Filth"
    xml.description "No seriously"
    xml.link comfy_blog_posts_url(@cms_site.path)

    @blog_posts.each do |post|
      url = comfy_blog_post_url(@cms_site.path, post.year, post.month, post.slug)

      xml.item do
        xml.title post.title
        xml.description post.content_cache.html_safe
        xml.pubDate post.published_at.to_s(:rfc822)
        xml.link url
        xml.guid url
      end
    end
  end
end
