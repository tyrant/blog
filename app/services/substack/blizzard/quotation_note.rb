# frozen_string_literal: true

# Builds a Substack Note body_json from a SubstackQuotation, for the blizzard's
# quotation reposts. Adapted to the Note schema (blockquote + bold/italic/link
# marks; Notes have no heading or paragraph alignment): a bold title — "another
# <COMPLIMENT> review (#N)" — the italic quote, a 🔗 link to the review on its
# Reviews page, the linked author, and an "all **M** at my Reviews Pages" link.
# The post itself rides along as a preview-card attachment (added by the ticker).
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
        standing = reviews_standing(quotation)
        {
          "type" => "doc",
          "attrs" => { "schemaVersion" => "v1" },
          "content" => [
            title(quotation, standing: standing),
            quote(quotation),
            source(quotation, standing: standing),
            attribution(quotation),
            more_reviews(quotation, standing: standing)
          ]
        }
      end

      # "Sexyverse Advice: another CRACKING review (#3)" — the number is the
      # quotation's place on the Reviews pages, left off when it isn't on them.
      def title(quotation, standing: reviews_standing(quotation))
        number, _total = standing
        review = number ? " review (##{number})" : " review"
        {
          "type" => "paragraph",
          "content" => [
            text("Sexyverse Advice: another ",
                 marks: [{ "type" => "bold" }]),
            text(random_compliment[0]&.upcase,
                 marks: [{ "type" => "bold" }, { "type" => "italic" }]),
            text(review,
                 marks: [{ "type" => "bold" }])
          ]
        }
      end

      # Where the quotation sits on the Reviews pages, which list the featurable
      # quotations in manual order: [its 1-based place, or nil when it isn't on
      # them (no post URL, or unsaved), and how many the pages hold].
      def reviews_standing(quotation)
        ids = SubstackQuotation.featurable.by_position.pluck(:id)
        index = ids.index(quotation.id) if quotation.id
        [index && index + 1, ids.size]
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

      # The 🔗 points at the review's own spot on its Reviews page — or, for a
      # quotation the pages leave out, at the original comment.
      def source(quotation, standing: reviews_standing(quotation))
        number, _total = standing
        href = number ? SubstackSyncConfig.instance.review_url(number) : quotation.comment_url
        {
          "type" => "paragraph",
          "content" => [
            text("🔗 — "),
            text('blargh-placeholder-text',
                 marks: [link(href)]),
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
      # The bold "all N" counts every review on the Reviews pages.
      def more_reviews(quotation, standing: reviews_standing(quotation))
        verbs = ['Enjoy', 'Peruse', 'Snuffle up', 'Savour', 'Yum up', 'Chow down', 'Gnaw', 'Gobble', 'Hoick']
        _number, total = standing

        {
          "type" => "paragraph",
          "content" => [
            text("#{verbs.sample} all "),
            text(total.to_s,
                 marks: [{ "type" => "bold" }]),
            text(" at my "),
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
