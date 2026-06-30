# frozen_string_literal: true

module ApplicationHelper
  # Inline links to each Note in a blizzard group, labelled by post date (fallback "#n").
  def blizzard_note_links(notes)
    links = Array(notes).each_with_index.map do |note, index|
      parsed = Time.zone.parse(note["timestamp"].to_s) rescue nil
      label  = parsed ? parsed.strftime("%-d %b %Y") : "##{index + 1}"
      link_to(label, note["url"], target: "_blank", rel: "noopener")
    end
    safe_join(links, " · ")
  end
end
