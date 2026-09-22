# frozen_string_literal: true

# Builds a Substack Note body_json from a SubstackQuotation, for the blizzard's
# quotation reposts. Adapted to the Note schema (blockquote + bold/italic/link
# marks; Notes have no heading or paragraph alignment): a lead-in label — bold
# "Another <compliment> review" then an unbolded "(🔗)" whose 🔗 links the original
# comment — a bold post-title link, the italic quote, the linked author, and a
# "More reviews" link. The post itself rides along as a preview-card attachment
# (added by the ticker).
module Substack
  module Blizzard
    module QuotationNote
      module_function

      REVIEWS_URL = "https://mikeyclarke.substack.com/p/reviews"

      def build(quotation)
        { 
          "type" => "doc", 
          "attrs" => { "schemaVersion" => "v1" },
          "content" => [
            label(quotation),
            title(quotation),
            quote(quotation),
            attribution(quotation),
            more_reviews
          ]
        }
      end

      def label(quotation)
        heading = ["Sexyverse Advice: another", random_compliment&.upcase, "review"].compact.join(" ")

        {
          "type" => "paragraph",
          "content" => [
            text(heading,
                 marks: [{ "type" => "bold" }]),
            text(" (🔗"),
            text(quotation.comment_url,
                 marks: [link(quotation.comment_url)]),
            text("):")
          ]
        }
      end

      def title(quotation)
        { 
          "type" => "paragraph",
          "content" => [
            text(quotation.post_title,
                 marks: [{ "type" => "bold" }, 
                 link(quotation.post_url)])
          ]
        }
      end

      def quote(quotation)
        {
          "type" => "blockquote",
          "content" => [{
            "type" => "paragraph",
            "content" => [
              text("“#{quotation.quotation}”",
                   marks: [{ "type" => "italic" }])
            ]
          }]
        }
      end

      def attribution(quotation)
        { 
          "type" => "paragraph",
          "content" => [
            text("— #{random_quantity&.capitalize} of thanks to "),
            text(quotation.author_name, 
                 marks: [link(quotation.author_url)]),
            text(", they're "),
            text(random_compliment,
                 marks: [{ 'type' => 'bold' }, { 'type' => 'italic' }]),
            text(", do check 'em out.")
          ]
        }
      end

      # Substack strips an explicit link mark to the reviews page (a page, not a
      # card-able post), but auto-linkifies a bare URL sitting in plain text — so
      # emit the URL unmarked in parens and let Substack turn it into the link.
      def more_reviews
        verbs = ['Enjoy', 'Peruse', 'Snuffle up', 'Savour', 'Yum up', 'Chow down', 'Gnaw', 'Gobble', 'Hoick']

        { 
          "type" => "paragraph", 
          "content" => [
            text("#{verbs.sample} oodles more kudos at my Reviews Pages: (🔗"),
            text(REVIEWS_URL, marks: [link(REVIEWS_URL)]),
            text(")")
          ]
        }
      end

      def text(string, marks: [])
        node = {
          "type" => "text", 
          "text" => string.to_s 
        }
        node["marks"] = marks if marks.any?
        node
      end

      def link(href)
        { 
          "type" => "link", 
          "attrs" => { "href" => href }
        }
      end

      def random_compliment
        Array(SubstackSyncConfig.instance.subtitle_variables["compliment"]).sample
      end

      def random_quantity
        Array(SubstackSyncConfig.instance.subtitle_variables["quantity"]).sample
      end
    end
  end
end
