# frozen_string_literal: true

# A Substack post whose draft the syncers have edited, waiting on a manual
# publish. The syncers never publish anything themselves: they write the draft
# and record it here, the author makes any hand edits (e.g. turning @handles
# into mentions) and clicks Update in Substack's editor (with its 2FA), and
# reconcile! clears the entry once Substack shows that Update happened (or it's
# dismissed by hand).
class SubstackPendingPublish < ApplicationRecord
  scope :oldest_first, -> { order(:created_at) }

  # Mark draft_id as awaiting a manual publish — one entry per draft, carrying
  # the latest title.
  def self.record!(draft_id, title)
    pending = find_or_initialize_by(draft_id: draft_id)
    pending.title = title if title.present?
    pending.touch if pending.persisted?
    pending.save!
  end

  # Drop every entry in scope whose draft Substack now shows as published as-is
  # — i.e. the manual Update has happened since. Checked live, one GET per entry.
  # Best-effort: the admin pages call this on load, so any Substack failure
  # leaves the remaining entries pending rather than breaking the page (and one
  # failure — dead cookie, timeout — would usually fail the rest too, so stop).
  def self.reconcile!(scope = all, client: nil)
    pending = scope.to_a
    return if pending.empty?

    client ||= Substack::Client.new
    pending.each do |entry|
      entry.destroy! if published_as_drafted?(client.get_draft(entry.draft_id))
    end
  rescue => e
    Rails.logger.warn("[SubstackPendingPublish] reconcile stopped: #{e.message}")
  end

  # Substack keeps a post's live version (title/subtitle/body) beside its draft
  # (draft_*); they match once the draft has been published with no edits since.
  def self.published_as_drafted?(draft)
    draft["is_published"] &&
      draft["title"] == draft["draft_title"] &&
      draft["subtitle"] == draft["draft_subtitle"] &&
      comparable_body(draft["body"]) == comparable_body(draft["draft_body"])
  end

  # Substack's editor regenerates image nodeIds whenever a post is opened, so
  # they differ between the two copies even when the content doesn't.
  def self.comparable_body(json)
    strip_node_ids(JSON.parse(json.to_s))
  rescue JSON::ParserError
    json.to_s
  end

  def self.strip_node_ids(node)
    case node
    when Hash  then node.except("nodeId").transform_values { |v| strip_node_ids(v) }
    when Array then node.map { |v| strip_node_ids(v) }
    else node
    end
  end
  private_class_method :comparable_body, :strip_node_ids

  def editor_url
    SubstackSyncConfig.instance.draft_editor_url(draft_id)
  end
end
