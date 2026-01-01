# frozen_string_literal: true

RSpec.configure do |config|
  config.around(:each, versioning: true) do |example|
    was_enabled = PaperTrail.enabled?
    PaperTrail.enabled = true
    example.run
    PaperTrail.enabled = was_enabled
  end
end
