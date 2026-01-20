class AddCategorySubstack < ActiveRecord::Migration[8.0]
  def up
    Comfy::Cms::Category.create! label: 'Substack',
                                 site: Comfy::Cms::Site.find_by(identifier: 'blog'), 
                                 categorized_type: 'Comfy::Blog::Post'
  end

  def down
    Comfy::Cms::Category.find_by(label: 'Substack').destroy!
  end
end
