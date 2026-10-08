# frozen_string_literal: true

# A Substack post whose draft edits the syncers pushed but couldn't publish
# live, because Substack wants a fresh 2FA sign-in before any publish
# (reauthentication_required) — which a stored session cookie can't give it.
# Draft writes still go through, so the edit is waiting in the draft: the admin
# lists these for a manual Update in Substack's editor, then they're dismissed.
class SubstackPendingPublish < ApplicationRecord
  scope :oldest_first, -> { order(:created_at) }

  # Publish draft_id live, or — when Substack demands re-authentication — record
  # it as pending instead of failing the sync. Any other error still raises.
  # Returns true when published, false when queued for a manual publish.
  def self.publish(client, draft_id, title:)
    client.publish_draft(draft_id)
    where(draft_id: draft_id).delete_all
    true
  rescue Substack::Client::ReauthRequired
    record!(draft_id, title)
    false
  end

  def self.record!(draft_id, title)
    pending = find_or_initialize_by(draft_id: draft_id)
    pending.title = title if title.present?
    pending.touch if pending.persisted?
    pending.save!
  end

  def editor_url
    "https://#{SubstackSyncConfig.instance.publication_host}/publish/post/#{draft_id}"
  end
end
