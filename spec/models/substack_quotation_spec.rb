# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackQuotation do
  describe 'validations' do
    it { expect(described_class.new).to_not be_valid }
    it { expect(described_class.new(quotation: 'q', comment_url: 'u')).to be_valid }
    it { expect(described_class.new(quotation: 'q')).to_not be_valid }
    it { expect(described_class.new(comment_url: 'u')).to_not be_valid }
  end

  describe '#populate_from_substack!' do
    subject(:quotation) { described_class.new(quotation: 'blurb', comment_url: 'https://x/comment/5') }

    let(:client) { instance_double(Substack::Client) }

    before do
      allow(client).to receive(:get_note).with('5').and_return('item' => {
        'comment' => { 'name' => 'Bob', 'handle' => 'bob' },
        'post' => { 'title' => 'A Post', 'canonical_url' => 'https://x/p/a' }
      })
    end

    it 'fills post and author fields from the comment' do
      quotation.populate_from_substack!(client: client)
      expect(quotation).to have_attributes(
        post_url: 'https://x/p/a', post_title: 'A Post',
        author_name: 'Bob', author_url: 'https://substack.com/@bob'
      )
    end
  end
end
