# frozen_string_literal: true

class Comfy::Cms::Revision < ActiveRecord::Base

  self.table_name = "comfy_cms_revisions"

  # Custom coder to handle both YAML and JSON data for backward compatibility
  class YamlJsonCoder
    def self.load(value)
      return nil if value.nil?
      
      # Try JSON first
      begin
        JSON.parse(value)
      rescue JSON::ParserError
        # Fall back to YAML if JSON parsing fails
        begin
          YAML.safe_load(value, permitted_classes: [Symbol])
        rescue Psych::SyntaxError
          # If both fail, return nil
          nil
        end
      end
    end

    def self.dump(obj)
      JSON.generate(obj)
    end
  end

  serialize :data, coder: YamlJsonCoder

  # -- Relationships --------------------------------------------------------
  belongs_to :record, polymorphic: true, optional: false

end
