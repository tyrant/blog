# frozen_string_literal: true

require "nokogiri"

# Drafts sample reply comments for a Substack post: fetch the post, feed its text
# to Claude with an (admin-editable) tone brief and count/balance/length knobs,
# and return a labelled agree/disagree mix for the user to edit and post himself.
# Falls back to placeholder replies until an Anthropic API key is configured.
module Substack
  class ReplyGenerator
    include ServiceInterface

    arguments :url, instructions: nil, count: 6, split: "balanced", length: "1-3", model: nil,
                    substack: nil, anthropic: nil

    # The editable brief seeded into ReplyDrafterConfig. Voice/style/humour live
    # here; the output-format rule below is fixed so edits can't break parsing.
    DEFAULT_INSTRUCTIONS = <<~TXT
      You draft short sample reply comments to a Substack post, for a reader who will edit and post them himself.
      Each reply should either largely agree with the post, or respectfully and constructively disagree with it.
      Every reply must:
      - carry good humour, empathy and goodwill, and sound like a warm, witty human — never a bot
      - engage with the post's actual substance, not generic praise
      - contain no greeting, no sign-off, no hashtags, and no emoji unless one genuinely fits
    TXT

    FORMAT_RULE = 'Respond with ONLY a JSON array of objects, each {"stance": "agree"|"disagree", "text": "..."} — no prose, no code fences.'

    SPLIT_PHRASES = {
      "balanced"        => "with a roughly even mix of agreeing and disagreeing replies",
      "mostly_agree"    => "mostly agreeing, with one or two respectful disagreements",
      "mostly_disagree" => "mostly respectfully disagreeing, with one or two agreements",
      "agree"           => "all agreeing with the post",
      "disagree"        => "all respectfully and constructively disagreeing"
    }.freeze

    LENGTH_PHRASES = {
      "1"   => "a single punchy sentence",
      "1-2" => "one or two sentences",
      "1-3" => "one to three sentences",
      "2-3" => "two to three sentences"
    }.freeze

    BODY_LIMIT = 6000

    def execute
      @substack  ||= Substack::Client.new
      @anthropic ||= Anthropic::Client.new

      post = @substack.get_post(@url)
      return stub_replies unless @anthropic.configured?

      system = "#{(@instructions.presence || DEFAULT_INSTRUCTIONS).strip}\n\n#{FORMAT_RULE}"
      model  = @model.presence || Anthropic::Client::DEFAULT_MODEL
      parse(@anthropic.complete(system: system, prompt: user_prompt(post), model: model))
    end

    private

    def user_prompt(post)
      <<~TXT
        Post title: #{post["title"]}
        Post subtitle: #{post["subtitle"]}

        Post body:
        #{html_to_text(post["body_html"].to_s)[0, BODY_LIMIT]}

        Draft #{@count} sample replies, #{split_phrase}, each #{length_phrase}.
      TXT
    end

    def split_phrase
      SPLIT_PHRASES[@split] || SPLIT_PHRASES["balanced"]
    end

    def length_phrase
      LENGTH_PHRASES[@length] || LENGTH_PHRASES["1-3"]
    end

    def html_to_text(html)
      doc = Nokogiri::HTML.fragment(html)
      doc.css("p, h1, h2, h3, h4, h5, h6, li, blockquote, br").each { |node| node.after("\n") }
      doc.text.gsub(/\n{3,}/, "\n\n").strip
    end

    # Tolerate stray prose/fences around the JSON array.
    def parse(raw)
      array = raw.to_s[/\[.*\]/m] || "[]"
      Array(JSON.parse(array)).filter_map do |reply|
        next unless reply.is_a?(Hash) && reply["text"].present?

        { "stance" => (reply["stance"] == "disagree" ? "disagree" : "agree"), "text" => reply["text"].to_s.strip }
      end
    rescue JSON::ParserError
      []
    end

    def stub_replies
      [
        { "stance" => "agree",    "text" => "Really resonated with this — you put words to something I'd felt for ages but never pinned down. (stub reply — add an Anthropic API key to generate real ones.)" },
        { "stance" => "agree",    "text" => "This was exactly the nudge I needed today; thank you for writing it so generously. (stub)" },
        { "stance" => "disagree", "text" => "Love the spirit here, though I'd gently push back on one bit — my own experience went the other way, and I'm still glad it did. (stub)" },
        { "stance" => "disagree", "text" => "Warmly disagree on the central claim: I think the trade-off is trickier than it looks. Admire how you framed it, mind. (stub)" }
      ]
    end
  end
end
