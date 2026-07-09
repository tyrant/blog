# frozen_string_literal: true

# Converts a Comfy post's content_cache HTML into the ProseMirror "doc" that
# Substack's draft_body expects. Node/mark names mirror Substack's own editor
# output (heading/blockquote/bullet_list/ordered_list/list_item/captionedImage,
# marks strong/em/link). Unknown elements are unwrapped so their text survives.
#
# Images are resolved through image_resolver (src -> CDN url); the syncer wires
# it to upload each image to Substack. A nil result drops the image.
module Substack
  class HtmlToProseMirror
    include ServiceInterface

    arguments :html, image_resolver: nil

    BLOCK_TAGS     = %w[p h1 h2 h3 h4 h5 h6 blockquote ul ol hr].freeze
    CONTAINER_TAGS = %w[div section article header footer aside main figure figcaption].freeze

    def execute
      @image_resolver ||= ->(src) { src }
      fragment = Nokogiri::HTML.fragment(@html.to_s)
      { "type" => "doc", "content" => blocks(fragment.children) }
    end

    private

    # Turn a node list into block nodes, gathering loose inline content into
    # paragraphs as it goes.
    def blocks(nodes)
      out = []
      inline = []
      nodes.each do |node|
        if inline_level?(node)
          inline << node
        else
          out.concat(flush(inline))
          inline = []
          out.concat(block_nodes(node))
        end
      end
      out.concat(flush(inline))
      out
    end

    def inline_level?(node)
      return true if node.text?
      return false unless node.element?

      !(BLOCK_TAGS.include?(node.name) || CONTAINER_TAGS.include?(node.name) || node.name == "img")
    end

    def block_nodes(node)
      return [] unless node.element?

      case node.name
      when "p"                             then paragraph_or_image(node)
      when "h1", "h2", "h3", "h4", "h5", "h6" then heading(node)
      when "blockquote"                    then [blockquote(node)]
      when "ul"                            then [list(node, "bullet_list", { "tight" => false })]
      when "ol"                            then [list(node, "ordered_list", { "order" => 1, "tight" => false })]
      when "hr"                            then [{ "type" => "horizontal_rule" }]
      when "img"                           then [captioned_image(node)].compact
      else blocks(node.children)
      end
    end

    def flush(nodes)
      content = inline_content(nodes)
      return [] if content.all? { |n| n["type"] == "text" && n["text"].strip.empty? && !n["marks"] }

      [{ "type" => "paragraph", "content" => content }]
    end

    def paragraph_or_image(node)
      out = []
      content = inline_content(node.children)
      out << { "type" => "paragraph", "content" => content } if content.any?
      node.css("img").each { |img| ci = captioned_image(img); out << ci if ci }
      out
    end

    def heading(node)
      content = inline_content(node.children)
      return [] if content.empty?

      [{ "type" => "heading", "attrs" => { "level" => node.name[1].to_i.clamp(1, 6) }, "content" => content }]
    end

    def blockquote(node)
      content = blocks(node.children)
      content = [{ "type" => "paragraph" }] if content.empty?
      { "type" => "blockquote", "content" => content }
    end

    def list(node, type, attrs)
      items = node.element_children.select { |c| c.name == "li" }.map do |li|
        content = blocks(li.children)
        content = [{ "type" => "paragraph" }] if content.empty?
        { "type" => "list_item", "content" => content }
      end
      { "type" => type, "attrs" => attrs, "content" => items }
    end

    def captioned_image(img)
      src = img["src"].to_s.strip
      return nil if src.empty?

      resolved = @image_resolver.call(src)
      return nil if resolved.to_s.empty?

      { "type" => "captionedImage", "content" => [{
        "type"  => "image2",
        "attrs" => { "src" => resolved, "alt" => img["alt"], "title" => img["title"],
                     "height" => nil, "width" => nil, "resizeWidth" => nil,
                     "bytes" => nil, "type" => nil, "href" => nil }
      }] }
    end

    def inline_content(children, marks = [])
      out = []
      children.each do |child|
        if child.text?
          out << text_node(child.text, marks) unless child.text.empty?
        elsif child.element?
          case child.name
          when "strong", "b" then out.concat(inline_content(child.children, marks + [{ "type" => "strong" }]))
          when "em", "i"     then out.concat(inline_content(child.children, marks + [{ "type" => "em" }]))
          when "a"           then out.concat(inline_content(child.children, marks + [link_mark(child)]))
          when "br", "img"   then next
          else out.concat(inline_content(child.children, marks))
          end
        end
      end
      out
    end

    def text_node(text, marks)
      node = { "type" => "text", "text" => text }
      node["marks"] = marks unless marks.empty?
      node
    end

    def link_mark(anchor)
      { "type" => "link", "attrs" => { "href" => anchor["href"].to_s, "title" => nil } }
    end
  end
end
