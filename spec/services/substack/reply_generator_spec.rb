# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::ReplyGenerator do
  subject(:generate) { described_class.execute(url: url, substack: substack, anthropic: anthropic) }

  let(:url) { 'https://pub.substack.com/p/some-post' }
  let(:substack) { instance_double(Substack::Client) }
  let(:anthropic) { instance_double(Anthropic::Client) }
  let(:post) { { 'title' => 'A Title', 'subtitle' => 'A sub', 'body_html' => '<p>Para one.</p><p>Para two.</p>' } }

  before { allow(substack).to receive(:get_post).with(url).and_return(post) }

  context 'when the Anthropic client is configured' do
    before do
      allow(anthropic).to receive(:configured?).and_return(true)
      allow(anthropic).to receive(:complete).and_return(
        '[{"stance":"agree","text":"Loved this."},{"stance":"disagree","text":"Gently disagree."}]'
      )
    end

    it 'returns the parsed replies' do
      expect(generate).to eq([
        { 'stance' => 'agree', 'text' => 'Loved this.' },
        { 'stance' => 'disagree', 'text' => 'Gently disagree.' }
      ])
    end

    it 'feeds the post title and body text to the model' do
      generate
      expect(anthropic).to have_received(:complete) do |system:, prompt:, **|
        expect(system).to include('agree')
        expect(prompt).to include('A Title').and include('Para one.').and include('Para two.')
      end
    end

    it 'defaults an unknown stance to agree' do
      allow(anthropic).to receive(:complete).and_return('[{"stance":"maybe","text":"Hmm."}]')
      expect(generate.first['stance']).to eq 'agree'
    end

    it 'tolerates prose or fences around the JSON' do
      allow(anthropic).to receive(:complete).and_return("Sure!\n```json\n[{\"stance\":\"agree\",\"text\":\"Yes.\"}]\n```")
      expect(generate).to eq([{ 'stance' => 'agree', 'text' => 'Yes.' }])
    end

    it 'returns an empty list on unparseable output' do
      allow(anthropic).to receive(:complete).and_return('not json at all')
      expect(generate).to eq([])
    end
  end

  context 'when the Anthropic client is not configured' do
    before { allow(anthropic).to receive(:configured?).and_return(false) }

    it 'returns placeholder stub replies without calling the model' do
      expect(anthropic).to_not receive(:complete)
      expect(generate).to all(include('stance', 'text'))
    end

    it 'still fetches the post' do
      generate
      expect(substack).to have_received(:get_post).with(url)
    end
  end
end
