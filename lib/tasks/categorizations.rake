# frozen_string_literal: true

namespace :categorizations do
  desc "Report what ScratchpadParser would write to each Post's categorizations (no writes)"
  task backfill_dry_run: :environment do
    Categorizations::Backfill.run(commit: false)
  end

  desc "Backfill categorization #url and #data from each Post's #scratchpad"
  task backfill: :environment do
    Categorizations::Backfill.run(commit: true)
  end
end

module Categorizations
  module Backfill
    module_function

    def run(commit:)
      posts = Comfy::Blog::Post.where.not(scratchpad: [nil, ""]).includes(:categories, categorizations: :category)
      flagged = []

      posts.find_each do |post|
        result = ScratchpadParser.call(post)

        puts "POST #{post.id} #{post.title.to_s[0, 50]}"
        result.categorizations.each do |label, attrs|
          puts "  #{label}: url=#{attrs[:url].inspect} data=#{attrs[:data].to_json}"
          apply(post, label, attrs) if commit
        end
        result.flags.each { |f| puts "  ! #{f}" }
        result.leftover.each { |l| puts "  ~ left in scratchpad: #{l}" }

        flagged << post.id if result.flags.any?
      end

      puts "\n#{commit ? 'Committed' : 'Dry run'}. #{posts.count} posts. Flagged for review: #{flagged.join(', ')}"
    end

    def apply(post, label, attrs)
      categorization = post.categorizations.detect { |c| c.category.label == label }
      return unless categorization

      categorization.update!(url: attrs[:url], data: attrs[:data])
    end
  end
end
