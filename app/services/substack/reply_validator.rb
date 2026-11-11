# frozen_string_literal: true

# Checks drafted replies against the rules a JSON schema can't express, phrased for feeding back to the model.
module Substack
  class ReplyValidator
    LINK   = %r{https?://|www\.|\b[a-z0-9-]+\.(?:com|net|org|io|co|nz|uk|au|ai|app|dev|me|ly|xyz)\b}i
    EMAIL  = /[\w.+-]+@[\w-]+\.[\w.-]+/
    HANDLE = /(?<![\w@.])@\w+/
    # A sentence ends at . ! ? or … (plus any closing quote) when the next one starts with a capital or digit.
    SENTENCE_BREAK = /(?<=[.!?…])["”’')\]]*\s+(?=["“‘'(\[]?[[:upper:][:digit:]])/
    CHARACTERS_PER_SENTENCE = 300

    def initialize(count:, split:, length:)
      @count  = count.to_i
      @split  = split.to_s
      @length = length.to_i.clamp(1, 10)
    end

    def set_problems(replies)
      [count_problem(replies), mix_problem(replies)].compact
    end

    def reply_problems(reply)
      text = reply["text"].to_s
      problems = []
      sentences = sentence_count(text)
      problems << "has #{sentences} sentences; the limit is #{@length}" if sentences > @length
      problems << "is #{text.length} characters long; the limit is #{@length * CHARACTERS_PER_SENTENCE}" if text.length > @length * CHARACTERS_PER_SENTENCE
      problems << "contains a link" if text.match?(LINK)
      if text.match?(EMAIL)
        problems << "contains an email address"
      elsif text.match?(HANDLE)
        problems << "contains an @handle"
      end
      problems
    end

    private

    def sentence_count(text)
      text.strip.split(SENTENCE_BREAK).count(&:present?)
    end

    def count_problem(replies)
      "I asked for #{@count} replies and got #{replies.size}" unless replies.size == @count
    end

    def mix_problem(replies)
      agrees    = replies.count { |reply| reply["stance"] == "agree" }
      disagrees = replies.size - agrees
      expected  = case @split
                  when "agree"           then "all of them should agree" unless disagrees.zero?
                  when "disagree"        then "all of them should disagree" unless agrees.zero?
                  when "mostly_agree"    then "most of them should agree" unless agrees > disagrees
                  when "mostly_disagree" then "most of them should disagree" unless disagrees > agrees
                  else                        "agreeing and disagreeing replies should be roughly even" unless (agrees - disagrees).abs <= 1
                  end
      "#{agrees} agree and #{disagrees} disagree, but #{expected}" if expected
    end
  end
end
