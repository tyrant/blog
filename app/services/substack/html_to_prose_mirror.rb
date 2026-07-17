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
    IMAGE_SIZE_CLASSES = { "img-large" => "large", "img-full" => "full" }.freeze
    # Display width per imageSize so images fill the Substack content column
    # rather than defaulting to their (sometimes narrower) native width. full/
    # wide get nil — Substack sizes those itself.
    RESIZE_WIDTHS = { "normal" => 728, "large" => 1200 }.freeze

    def execute
      @image_resolver ||= ->(src) { src }
      fragment = Nokogiri::HTML.fragment(@html.to_s)
      { "type" => "doc", "content" => fold_captions(blocks(fragment.children)) }
    end

    private

    # A paragraph explicitly marked <p class="caption"> directly after an image
    # folds into it as Substack's "caption" node. Opt-in: unmarked paragraphs
    # after an image stay body text. The "_caption" marker is transient (set in
    # paragraph_or_image) and always stripped here so it never reaches Substack.
    def fold_captions(blocks)
      blocks.each_with_object([]) do |block, out|
        prev = out.last
        marked = block["type"] == "paragraph" && block.delete("_caption")
        if marked && block["content"].present? &&
            prev && prev["type"] == "captionedImage" &&
            prev["content"].none? { |child| child["type"] == "caption" }
          prev["content"] << { "type" => "caption", "content" => block["content"] }
        else
          out << block
        end
      end
    end

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

      !(BLOCK_TAGS.include?(node.name) || CONTAINER_TAGS.include?(node.name) || %w[img iframe].include?(node.name))
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
      when "iframe"                        then [youtube_node(node["src"])].compact
      else blocks(node.children)
      end
    end

    def flush(nodes)
      content = finalize_inline(inline_content(nodes))
      return [] if content.empty?

      [{ "type" => "paragraph", "content" => content }]
    end

    # HTML collapses whitespace to single spaces and trims it at block edges;
    # text_node collapses runs, this trims the leading/trailing space off a
    # block's inline content and drops any node emptied by it (so stray source
    # newlines don't become blank paragraphs or trailing newlines on Substack).
    def finalize_inline(content)
      return content if content.empty?

      content = content.dup
      content[0]  = strip_text(content[0], :lstrip) if content[0]["type"] == "text"
      content[-1] = strip_text(content[-1], :rstrip) if content[-1]["type"] == "text"
      content.reject { |node| node["type"] == "text" && node["text"].empty? }
    end

    def strip_text(node, method)
      node.merge("text" => node["text"].to_s.public_send(method))
    end

    def paragraph_or_image(node)
      # A paragraph that is nothing but a YouTube URL/link becomes a video player,
      # matching Substack's own paste-a-link behaviour.
      video = paragraph_youtube(node)
      return [video] if video

      out = []
      content = finalize_inline(inline_content(node.children))
      if content.any?
        paragraph = { "type" => "paragraph", "content" => content }
        paragraph["_caption"] = true if node["class"].to_s.split.include?("caption")
        out << paragraph
      end
      node.css("img").each { |img| ci = captioned_image(img); out << ci if ci }
      node.css("iframe").each { |frame| yt = youtube_node(frame["src"]); out << yt if yt }
      out
    end

    def paragraph_youtube(node)
      return nil if node.css("img, iframe").any?

      link = node.at_css("a")
      url = if link && node.text.strip == link.text.strip
              link["href"]
            elsif node.text.strip.match?(%r{\Ahttps?://\S+\z})
              node.text.strip
            end
      url && youtube_node(url)
    end

    # Substack's YouTube embed node. Only real YouTube URLs become players; any
    # other iframe/url yields nil (dropped).
    def youtube_node(url)
      id = youtube_id(url)
      return nil unless id

      { "type" => "youtube2", "attrs" => { "videoId" => id, "startTime" => youtube_start(url), "endTime" => nil } }
    end

    def youtube_id(url)
      str = url.to_s
      return nil unless str.match?(/youtu\.?be/i)

      str[%r{(?:youtu\.be/|/embed/|/shorts/|/v/)([\w-]{11})}, 1] || str[%r{[?&]v=([\w-]{11})}, 1]
    end

    def youtube_start(url)
      match = url.to_s.match(/[?&](?:t|start)=(\d+)/)
      match && match[1].to_i
    end

    def heading(node)
      out = []
      content = finalize_inline(inline_content(node.children))
      out << { "type" => "heading", "attrs" => { "level" => node.name[1].to_i.clamp(1, 6) }, "content" => content } if content.any?
      # An <img> inside a heading (some posts nest their main image in an <h2>)
      # would otherwise be dropped by inline_content — pull it out as its own block.
      node.css("img").each { |img| ci = captioned_image(img); out << ci if ci }
      out
    end

    def blockquote(node)
      content = quote_paragraphs(node)
      content = [{ "type" => "paragraph" }] if content.empty?
      { "type" => "blockquote", "content" => content }
    end

    # Redactor won't keep <p> inside a blockquote — it stores multiple paragraphs
    # as <br>-separated inline runs. Substack has no line-break node, so split each
    # run of <br>s back into a paragraph boundary (its only way to show the breaks).
    def quote_paragraphs(node)
      return blocks(node.children) if node.element_children.any? { |c| block_tag?(c.name) }

      split_on_breaks(node.children).filter_map do |run|
        content = finalize_inline(inline_content(run))
        { "type" => "paragraph", "content" => content } if content.any?
      end
    end

    def block_tag?(name)
      BLOCK_TAGS.include?(name) || CONTAINER_TAGS.include?(name)
    end

    # Groups children into runs split on <br>; whitespace-only runs between double
    # <br>s drop out later in finalize_inline, so a run of breaks yields one boundary.
    def split_on_breaks(children)
      runs = [[]]
      children.each do |child|
        if child.element? && child.name == "br"
          runs << [] unless runs.last.empty?
        else
          runs.last << child
        end
      end
      runs
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

      size = image_size(img)
      { "type" => "captionedImage", "content" => [{
        "type"  => "image2",
        "attrs" => { "src" => resolved, "alt" => img["alt"], "title" => img["title"],
                     "height" => nil, "width" => nil, "resizeWidth" => RESIZE_WIDTHS[size],
                     "bytes" => nil, "type" => nil, "href" => nil, "imageSize" => size }
      }] }
    end

    # An "img-large"/"img-full" class on the <img> maps to Substack's imageSize
    # (its only real sizes beyond the default "normal"); no such class means normal.
    def image_size(img)
      classes = img["class"].to_s.split
      IMAGE_SIZE_CLASSES.each { |css_class, size| return size if classes.include?(css_class) }
      "normal"
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
      node = { "type" => "text", "text" => text.gsub(/\s+/, " ") }
      node["marks"] = marks unless marks.empty?
      node
    end

    def link_mark(anchor)
      { "type" => "link", "attrs" => { "href" => anchor["href"].to_s, "title" => nil } }
    end
  end
end
