namespace :activestorage do

  desc "Regenerate ActiveStorage URLs for Rails 6->8 upgrade"
  task regenerate_urls: :environment do
    Comfy::Blog::Post.find_each do |post|
      next unless post.content_cache

      doc = Nokogiri::HTML(post.content_cache)
      images = doc.css('img[src*="rails/active_storage"]')

      next if images.empty?
      
      images.each do |img|
        old_src = img['src']
        blob_id = Comfy::Blog::Post.blob_id_from_src(src: old_src)
        blob = ActiveStorage::Blob.find(blob_id)
        new_src = Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: false, host: ENV['ROOT_URL'])
        img['src'] = new_src
      end

      post.update_column :content_cache, doc.to_html
    end
  end
end
