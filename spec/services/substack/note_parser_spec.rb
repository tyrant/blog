# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::NoteParser do

  describe '.comment_id_from_url' do
    it { expect(described_class.comment_id_from_url('https://substack.com/profile/4619740-mikey-clarke/note/c-267421089')).to eq '267421089' }
    it { expect(described_class.comment_id_from_url('https://substack.com/@mikeyclarke/note/c-267421568')).to eq '267421568' }
    it { expect(described_class.comment_id_from_url('https://mikeyclarke.substack.com/p/some-post')).to be_nil }
  end

  describe '.comment' do
    it { expect(described_class.comment({ 'comment' => { 'id' => 1 } })).to eq({ 'id' => 1 }) }
    it { expect(described_class.comment({ 'item' => { 'comment' => { 'id' => 2 } } })).to eq({ 'id' => 2 }) }
    it { expect(described_class.comment({ 'id' => 3 })).to eq({ 'id' => 3 }) }
  end

  describe '.body_json' do
    it { expect(described_class.body_json({ 'body_json' => { 'a' => 1 } })).to eq({ 'a' => 1 }) }
    it { expect(described_class.body_json({ 'bodyJson' => { 'b' => 2 } })).to eq({ 'b' => 2 }) }
  end

  describe '.timestamp' do
    it { expect(described_class.timestamp({ 'date' => '2025-08-01T00:00:00Z' })).to eq '2025-08-01T00:00:00Z' }
    it { expect(described_class.timestamp({ 'createdAt' => '2025-08-02' })).to eq '2025-08-02' }
  end

  describe '.likes' do
    it { expect(described_class.likes({ 'reaction_count' => 9 })).to eq 9 }
    it { expect(described_class.likes({ 'reaction_count' => 0, 'reactions' => { '❤' => 3 } })).to eq 0 }
    it { expect(described_class.likes({ 'reactions' => { '❤' => 3, '🔥' => 2 } })).to eq 5 }
    it { expect(described_class.likes({})).to eq 0 }
    it { expect(described_class.likes(nil)).to eq 0 }
  end

  describe '.append_post_url' do
    let(:body) { { 'type' => 'doc', 'content' => [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'hello' }] }] } }
    let(:url) { 'https://mikeyclarke.substack.com/p/foo' }

    it { expect(described_class.append_post_url(body, url)['content'].last['content'].first['text']).to eq url }
    it { expect(described_class.append_post_url(body, url)['content'].last['content'].first['marks']).to eq [{ 'type' => 'link', 'attrs' => { 'href' => url } }] }

    it 'is idempotent once the post is linked' do
      once = described_class.append_post_url(body, url)
      expect(described_class.append_post_url(once, url)).to eq once
    end

    it 'does not mutate the input' do
      described_class.append_post_url(body, url)
      expect(body['content'].size).to eq 1
    end

    it { expect(described_class.append_post_url(nil, url)).to be_nil }
    it { expect(described_class.append_post_url(body, '')).to eq body }
  end

  describe '.text_to_body_json' do
    it { expect(described_class.text_to_body_json('hello')).to eq({ 'type' => 'doc', 'attrs' => { 'schemaVersion' => 'v1' }, 'content' => [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'hello' }] }] }) }

    it 'round-trips through plaintext' do
      expect(described_class.plaintext(described_class.text_to_body_json("a\nb"))).to eq "a\nb"
    end

    it 'uses an empty paragraph for blank lines' do
      expect(described_class.text_to_body_json("a\n\nb")['content'][1]).to eq({ 'type' => 'paragraph' })
    end
  end

  describe '.strip_post_url' do
    let(:url) { 'https://mikeyclarke.substack.com/p/foo' }
    let(:base) { { 'type' => 'doc', 'content' => [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'hi' }] }] } }

    it 'removes the trailing post-url paragraph (inverse of append)' do
      expect(described_class.strip_post_url(described_class.append_post_url(base, url), url)).to eq base
    end

    it 'is a no-op when there is no trailing post url' do
      expect(described_class.strip_post_url(base, url)).to eq base
    end

    it { expect(described_class.strip_post_url(nil, url)).to be_nil }
  end

  describe '.parse_human_timestamp' do
    # June = NZST (UTC+12), so 19:00 NZ -> 07:00 UTC
    it { expect(described_class.parse_human_timestamp('21 Jun 2025 at 19:00')).to eq '2025-06-21T07:00:00Z' }
    it { expect(described_class.parse_human_timestamp('21 Jun at 19:00')).to match(/\A\d{4}-06-21T07:00:00Z\z/) }
    it 'accepts an ISO string too' do
      expect(described_class.parse_human_timestamp('2025-06-21T07:00:00Z')).to eq '2025-06-21T07:00:00Z'
    end
    it { expect(described_class.parse_human_timestamp('')).to be_nil }
    it { expect(described_class.parse_human_timestamp('not a date')).to be_nil }
  end

  describe '.plaintext' do
    let(:body_json) do
      {
        'type' => 'doc',
        'content' => [
          { 'type' => 'paragraph', 'content' => [
            { 'type' => 'text', 'text' => 'Hello ' },
            { 'type' => 'text', 'text' => 'bold', 'marks' => [{ 'type' => 'bold' }] }
          ] },
          { 'type' => 'paragraph', 'content' => [
            { 'type' => 'text', 'text' => 'link', 'marks' => [{ 'type' => 'link', 'attrs' => { 'href' => 'https://x.com' } }] }
          ] }
        ]
      }
    end

    it { expect(described_class.plaintext(body_json)).to eq "Hello bold\nlink" }
    it { expect(described_class.plaintext(nil)).to eq '' }
  end

  describe '.normalize' do
    it { expect(described_class.normalize("  a\n b   c ")).to eq 'a b c' }
  end
end
