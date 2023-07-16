class RenameVeryBadAdvicetoShiteAdvice < ActiveRecord::Migration[6.1]
  def up
    vba = Comfy::Cms::Category.find_by(label: 'Very Bad Advice')
    vba&.update!(label: 'Shite Advice')
  end

  def down
    sa = Comfy::Cms::Category.find_by(label: 'Shite Advice')
    sa&.update!(label: 'Very Bad Advice')
  end
end
