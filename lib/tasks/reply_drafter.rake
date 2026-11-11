# frozen_string_literal: true

namespace :reply_drafter do
  desc "Run Reply Drafter on the test posts against the real API (spends credits). MODEL=<id> picks the model."
  task eval: :environment do
    abort "No Anthropic API key configured." if Substack::ReplyGenerator.api_key.blank?

    puts Substack::ReplyEval.report(Substack::ReplyEval.execute(model: ENV["MODEL"]))
  end
end
