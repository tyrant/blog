# frozen_string_literal: true

# Derives per-Categorization #url and #data from a Post's freeform #scratchpad.
# Only data-bearing categories that the Post actually has ticked are populated;
# everything else (drafts, untracked links, source notes) is reported as leftover.
class ScratchpadParser

  Result = Struct.new(:categorizations, :leftover, :flags, keyword_init: true)

  MEDIUM_PUBLISHED = %r{\Ahttps?://mikey-clarke\.medium\.com/.+-(?<id>[0-9a-f]+)(?:\?.*)?\z}
  MEDIUM_DRAFT     = %r{\Ahttps?://medium\.com/p/[0-9a-f]+/edit}
  SUBSTACK_POST    = %r{\Ahttps?://mikeyclarke\.substack\.com/p/}
  SUBSTACK_PUBLISH = %r{\Ahttps?://mikeyclarke\.substack\.com/publish/posts/detail/(?<id>\d+)/}
  SUBSTACK_ID_LINE = /\ASubsta[sc]k id=(?<id>\d+)/i
  SUBSTACK_NOTE    = %r{\Ahttps?://substack\.com/(?:profile/[^/]+|@[^/]+)/note/c-\d+}
  TWITTER          = %r{\Ahttps?://(?:twitter|x)\.com/\w+/status/(?<id>\d+)}
  LINKEDIN         = %r{\Ahttps?://(?:www\.)?linkedin\.com/}
  LINKEDIN_ID      = /(?:urn:li:share:|activity-)(?<id>\d+)/
  FB_ANY           = %r{\Ahttps?://(?:www\.)?facebook\.com/}
  FB_GROUP         = %r{\Ahttps?://(?:www\.)?facebook\.com/groups/}
  FB_PERSONAL      = %r{\Ahttps?://(?:www\.)?facebook\.com/(?!groups/)[^/]+/posts/}
  QUORA            = %r{\Ahttps?://[\w-]*\.?quora\.com/}
  NOTE             = /\A\(.*\)\z/

  def self.call(post)
    new(post).call
  end

  def initialize(post)
    @post  = post
    @lines = post.scratchpad.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
    @ticked = post.categories.pluck(:label)
    @consumed = []
    @flags = []
  end

  def call
    categorizations = {}
    categorizations["Medium"]   = medium   if ticked?("Medium")
    categorizations["Substack"] = substack if ticked?("Substack")
    categorizations["Twitter"]  = twitter  if ticked?("Twitter")
    categorizations["LinkedIn"] = linkedin if ticked?("LinkedIn")
    categorizations["FB"]       = facebook if ticked?("FB")
    categorizations["Quora"]    = quora    if ticked?("Quora")
    categorizations.compact!

    Result.new(
      categorizations: categorizations,
      leftover:        @lines - @consumed,
      flags:           @flags
    )
  end

  private

  def ticked?(label)
    @ticked.include?(label)
  end

  def consume(line)
    @consumed << line
    line
  end

  def find(regex)
    @lines.find { |l| l.match?(regex) }
  end

  def medium
    if (line = find(MEDIUM_PUBLISHED))
      consume(line)
      { url: line.sub(/\?.*\z/, ""), data: { "id" => line.match(MEDIUM_PUBLISHED)[:id] } }
    else
      @flags << "Medium ticked but no published mikey-clarke.medium.com URL"
      { url: nil, data: {} }
    end
  end

  def substack
    url   = find(SUBSTACK_POST)
    consume(url) if url

    id_line = find(SUBSTACK_ID_LINE)
    id      = id_line && consume(id_line).match(SUBSTACK_ID_LINE)[:id]

    publish = find(SUBSTACK_PUBLISH)
    if publish
      consume(publish)
      id ||= publish.match(SUBSTACK_PUBLISH)[:id]
    end

    notes = @lines.select { |l| l.match?(SUBSTACK_NOTE) }.map { |l| consume(l) }

    @flags << "Substack ticked but no canonical /p/ URL" if url.nil?
    @flags << "Substack ticked but no id" if id.nil?

    data = {}
    data["id"]    = id.to_i if id
    data["notes"] = notes if notes.any?
    { url: url, data: data }
  end

  def twitter
    line = find(TWITTER)
    return flagged("Twitter") if line.nil?

    consume(line)
    { url: line, data: { "id" => line.match(TWITTER)[:id] } }
  end

  def linkedin
    line = find(LINKEDIN)
    return flagged("LinkedIn") if line.nil?

    consume(line)
    data = (m = line.match(LINKEDIN_ID)) ? { "id" => m[:id] } : {}
    { url: line, data: data }
  end

  def facebook
    links = @lines.select { |l| l.match?(FB_ANY) }
    # Prefer a group permalink, then any non-personal link, else the personal cross-post.
    primary = links.find { |l| l.match?(FB_GROUP) } ||
              links.find { |l| !l.match?(FB_PERSONAL) } ||
              links.first
    extras  = links - [primary]
    note    = find(NOTE)

    links.each { |l| consume(l) }

    extra_list = extras.map.with_index do |url, i|
      entry = { "url" => url }
      entry["note"] = consume(note).gsub(/\A\(|\)\z/, "") if note && i.zero?
      entry
    end

    @flags << "FB ticked but no facebook.com URL" if primary.nil?

    data = {}
    data["extras"] = extra_list if extra_list.any?
    { url: primary, data: data }
  end

  def quora
    links = @lines.select { |l| l.match?(QUORA) }
    return flagged("Quora") if links.empty?

    links.each { |l| consume(l) }
    data = {}
    data["extras"] = links[1..].map { |url| { "url" => url } } if links.size > 1
    { url: links.first, data: data }
  end

  def flagged(label)
    @flags << "#{label} ticked but no matching URL"
    { url: nil, data: {} }
  end

end
