# frozen_string_literal: true

class SubstackReply < ApplicationRecord
  validates :target_url, :comment_url, :replied_at, presence: true
  validates :comment_url, uniqueness: true

  scope :chronological, -> { order(replied_at: :desc) }

  # Replies grouped by the account replied to, each group newest-first, and the
  # accounts themselves ordered by most-recent reply.
  def self.by_author(query = nil)
    threads = chronological.group_by(&:thread_key)
    if query.present?
      q = query.strip.downcase
      threads = threads.select { |_key, reps| reps.any? { |r| "#{r.author_handle} #{r.author_name}".downcase.include?(q) } }
    end

    # Attribute each whole thread to the account of its root reply (the one the
    # user entered the thread on), so a cross-author thread stays stitched under
    # one account rather than fragmenting across cards.
    cards = Hash.new { |hash, key| hash[key] = [] }
    threads.each_value do |reps|
      owner = reps.min_by { |r| [r.ancestor_ids.length, r.replied_at.to_i] }.author_handle.presence || "(unknown)"
      cards[owner].concat(reps)
    end
    cards.sort_by { |_owner, reps| -reps.map { |r| r.replied_at.to_i }.max }.to_h
  end

  # The top-level comment/note id of the thread this reply belongs to.
  def thread_key
    ancestor_ids.first || reply_comment_id
  end

  # The user's reply comment id (from the reply URL) and the ancestor comment ids
  # above it — the two together place a reply within a thread.
  def reply_comment_id
    Substack::NoteParser.comment_id_from_url(comment_url) || comment_url.to_s[%r{/comment/(\d+)}, 1]
  end

  def ancestor_ids
    ancestor_path.to_s.split(".")
  end

  # Order a set of replies as a thread forest: a reply nests under the deepest
  # other reply whose comment is among its ancestors. Returns [[reply, depth], …]
  # in pre-order — roots newest-first, each thread read oldest-first.
  def self.threaded(replies)
    by_id    = replies.index_by(&:reply_comment_id)
    children = Hash.new { |hash, key| hash[key] = [] }
    roots    = []

    replies.each do |reply|
      parent_id = reply.ancestor_ids.reverse.find { |id| by_id.key?(id) && by_id[id] != reply }
      parent_id ? children[parent_id] << reply : roots << reply
    end

    ordered = []
    visit = lambda do |reply, depth|
      ordered << [reply, depth]
      children[reply.reply_comment_id].sort_by(&:replied_at).each { |child| visit.call(child, depth + 1) }
    end
    roots.sort_by { |reply| -reply.replied_at.to_i }.each { |root| visit.call(root, 0) }
    ordered
  end
end
