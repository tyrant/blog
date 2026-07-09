# frozen_string_literal: true

namespace :substack do
  # The canonical post whose subtitle + footer boilerplate we mirror onto every
  # Substack draft. Re-run capture_footer against another draft to change it.
  REFERENCE_FOOTER_DRAFT_ID = "206216505"

  desc "Capture subtitle + footer boilerplate from a reference draft into SubstackSyncConfig"
  task :capture_footer, [:draft_id] => :environment do |_t, args|
    footer = Substack::FooterCapturer.execute(draft_id: args[:draft_id].presence || REFERENCE_FOOTER_DRAFT_ID)
    puts "Captured subtitle + #{footer.size} footer blocks."
  end

  desc "Seed the footer only if not already captured — safe to run on every deploy"
  task seed_footer: :environment do
    if SubstackSyncConfig.instance.footer_json.present?
      puts "Substack footer already seeded; skipping."
    else
      Rake::Task["substack:capture_footer"].invoke
    end
  rescue => e
    # Never fail a deploy over a transient Substack/API issue; next deploy retries.
    warn "[substack:seed_footer] skipped: #{e.message}"
  end
end
