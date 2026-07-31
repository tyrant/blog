# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlueskySyncConfig do
  describe 'validations' do
    subject(:config) { described_class.instance }

    it { expect(config).to be_persisted }

    it 'requires a handle on update' do
      config.update(handle: nil, app_password: 'pw')
      expect(config.errors[:handle]).to be_present
    end

    it 'requires an app password on update' do
      config.update(handle: 'me.bsky.social', app_password: nil)
      expect(config.errors[:app_password]).to be_present
    end
  end

  describe '.instance' do
    before { described_class.instance }

    it 'reuses the singleton row' do
      expect { described_class.instance }.to_not change(described_class, :count)
    end
  end

  describe '#lead_for' do
    subject(:lead) { config.lead_for(post) }

    let(:config) { described_class.new(lead: 'Default lead', lead_shite: 'Shite lead') }
    let(:site) { create :site }
    let(:layout) { create :layout, site: site }
    let(:post) { create :post, site: site, layout: layout }

    context 'a plain post' do
      it { expect(lead).to eq 'Default lead' }
    end

    context 'a Shite Advice post' do
      before { post.tags << Tag.create!(name: 'Shite Advice') }

      it { expect(lead).to eq 'Shite lead' }
    end

    context 'a Shite Advice post with no shite lead set' do
      let(:config) { described_class.new(lead: 'Default lead', lead_shite: nil) }
      before { post.tags << Tag.create!(name: 'Shite Advice') }

      it { expect(lead).to eq 'Default lead' }
    end
  end
end
