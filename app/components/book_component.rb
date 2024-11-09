class BookComponent < ViewComponent::Base
  
  def initialize(image_path:, link_path:, number:, title:, blurb:)
    @image_path = image_path
    @link_path = link_path
    @number = number
    @title = title
    @blurb = blurb
  end  
end
