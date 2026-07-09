# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::FooterCapturer do
  subject(:capture) { described_class.execute(draft_id: 42, client: client) }

  let(:client) { instance_double(Substack::Client) }
  let(:blocks) do
    [
      { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'article' }] },
      { 'type' => 'subscribeWidget' },
      { 'type' => 'button' }
    ]
  end

  before do
    allow(client).to receive(:get_draft).with(42)
      .and_return('draft_subtitle' => 'The subtitle', 'draft_body' => { 'content' => blocks }.to_json)
  end

  it 'stores the subtitle from the reference draft' do
    capture
    expect(SubstackSyncConfig.instance.subtitle).to eq 'The subtitle'
  end

  it 'stores the footer from the first subscribeWidget onward' do
    capture
    expect(SubstackSyncConfig.instance.footer_json.map { |b| b['type'] }).to eq %w[subscribeWidget button]
  end

  it 'returns the captured footer blocks' do
    expect(capture.size).to eq 2
  end

  context 'when the draft has no subscribeWidget' do
    let(:blocks) { [{ 'type' => 'paragraph' }] }

    it { expect { capture }.to raise_error(/subscribeWidget/) }
  end
end
