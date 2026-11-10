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
      PRONOUN_WORDING = {
        "she/her" => { "they_are" => "she's", "send_love" => "check her out and/or send her some love." },
        "he/him" => { "they_are" => "he's", "send_love" => "check him out and/or send him some love." }
      }.freeze
      NEUTRAL_WORDING = { "they_are" => "they're", "send_love" => "check 'em out and/or send them some love." }.freeze

      def build(quotation)
        { 
          "type" => "doc", 
          "attrs" => { "schemaVersion" => "v1" },
          "content" => [
            title(quotation),
            quote(quotation),
            source(quotation),
            attribution(quotation),
            more_reviews
          ]
        }
      end

      def title(quotation)
        {
          "type" => "paragraph",
          "content" => [
            text("Sexyverse Advice: another ",
                 marks: [{ "type" => "bold" }]),
            text(random_compliment[0]&.upcase,
                 marks: [{ "type" => "bold" }, { "type" => "italic" }]),
            text(" review",
                 marks: [{ "type" => "bold" }])
          ]
        }
      end

      def quote(quotation)
        {
          "type" => "blockquote",
          "content" => [{
            "type" => "paragraph",
            "content" => [
              text("\"#{quotation.quotation}\"",
                   marks: [{ "type" => "italic" }])
            ]
          }]
        }
      end

      def source(quotation)
        {
          "type" => "paragraph",
          "content" => [
            text("🔗 — "),
            text('blargh-placeholder-text',
                 marks: [link(quotation.comment_url)]),
            text('.')
          ]
        }
      end

      def attribution(quotation)
        { "type" => "paragraph", "content" => attribution_nodes(quotation) }
      end

      # "Bags of thanks to the *Most* Spiffy <author>, she's ***cracking***, do
      # check her out and/or send her some love." — two distinct random
      # compliments, so at least two must be configured. Shared with the Reviews
      # pages' signature (QuotationBlock.review_signature), which passes the post
      # schema's mark names and a linked-name author in place of the Note
      # schema's and the @mention.
      def attribution_nodes(quotation, bold: "bold", italic: "italic", author_node: author(quotation))
        compliments = random_compliment(n: 2)
        most_complimented = [
            text("Most ",
                  marks: [{ 'type' => italic }]),
            text("#{compliments[0].capitalize} ")
          ]
        wording = pronoun_wording(quotation)

        [
          text("#{random_quantity&.capitalize} of thanks to the "),
          *most_complimented,
          author_node,
          text(", #{wording["they_are"]} "),
          text(compliments[1],
               marks: [{ 'type' => bold }, { 'type' => italic }]),
          text(", do #{wording["send_love"]}")
        ]
      end

      def pronoun_wording(quotation)
        PRONOUN_WORDING.fetch(quotation.substack_user&.pronouns.to_s.downcase, NEUTRAL_WORDING)
      end

      # Labelled by handle: display names are often shared, so "@Name" search returns namesakes.
      def author(quotation)
        user = quotation.substack_user
        return text(user&.name, marks: [link(user&.profile_url)]) if user&.user_id.blank?

        {
          "type" => "substack_mention",
          "attrs" => {
            "id" => user.user_id,
            "label" => user.handle.presence || user.name,
            "mentionType" => "user",
            "url" => nil
          }
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
            text("#{verbs.sample} oodles more kudos at my "),
            text("Reviews Pages",
                  marks: [{ "type" => "bold" }, { "type" => "italic" }]),
            text(": "),
            text('blargh-placeholder-text',
                 marks: [link(REVIEWS_URL)]),
            text('.')
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

      def random_compliment(n: 1)
        Array(SubstackSyncConfig.instance.subtitle_variables["compliment"]).sample(n)
      end

      def random_quantity
        Array(SubstackSyncConfig.instance.subtitle_variables["quantity"]).sample
      end
    end
  end
end
