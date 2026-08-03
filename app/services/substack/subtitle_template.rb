# frozen_string_literal: true

# Renders a subtitle template: replaces each {{ var }} token with a random value
# drawn from variables[var] (an array of strings). Tokens whose variable is
# missing or empty are left untouched, so a mismatch is visible rather than
# silently blanked. Mirrors the client-side renderSubtitleTemplate used by the
# "generate sample" button.
module Substack
  module SubtitleTemplate
    TOKEN = /\{\{\s*(\w+)\s*\}\}/
    # Variables whose rendered value is upper-cased.
    UPPERCASE_KEYS = %w[compliment].freeze

    def self.render(template, variables)
      variables = {} unless variables.is_a?(Hash)
      template.to_s.gsub(TOKEN) do
        key = Regexp.last_match(1)
        values = variables[key]
        next Regexp.last_match(0) unless values.is_a?(Array) && values.any?

        value = values.sample.to_s
        UPPERCASE_KEYS.include?(key) ? value.upcase : value
      end
    end
  end
end
