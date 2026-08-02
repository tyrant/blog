# frozen_string_literal: true

# Renders a subtitle template: replaces each {{ var }} token with a random value
# drawn from variables[var] (an array of strings). Tokens whose variable is
# missing or empty are left untouched, so a mismatch is visible rather than
# silently blanked. Mirrors the client-side renderSubtitleTemplate used by the
# "generate sample" button.
module Substack
  module SubtitleTemplate
    TOKEN = /\{\{\s*(\w+)\s*\}\}/

    def self.render(template, variables)
      variables = {} unless variables.is_a?(Hash)
      template.to_s.gsub(TOKEN) do
        values = variables[Regexp.last_match(1)]
        values.is_a?(Array) && values.any? ? values.sample.to_s : Regexp.last_match(0)
      end
    end
  end
end
