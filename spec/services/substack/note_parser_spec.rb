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
