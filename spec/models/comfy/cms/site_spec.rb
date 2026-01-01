# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Cms::Site, type: :model do
  let!(:site) { create :site }

  before { reset_cms_config }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:identifier) }
    it { is_expected.to validate_presence_of(:hostname) }
    it { is_expected.to validate_uniqueness_of(:identifier) }

    context 'with invalid hostname format' do
      let(:invalid_site) { build :site, identifier: 'test', hostname: 'http://site.host' }

      it { expect(invalid_site).to_not be_valid }
    end

    context 'with valid hostname' do
      let(:valid_site) { build :site, identifier: 'test2', hostname: 'site.host' }

      it { expect(valid_site).to be_valid }
    end

    context 'with localhost and port' do
      let(:localhost_site) { build :site, identifier: 'test3', hostname: 'localhost:3000' }

      it { expect(localhost_site).to be_valid }
    end
  end

  describe 'path uniqueness validation' do
    context 'when same hostname and path' do
      let(:duplicate_site) { build :site, identifier: 'test', hostname: site.hostname, path: site.path }

      it { expect(duplicate_site).to_not be_valid }
    end

    context 'when same hostname but different path' do
      let(:different_path_site) { build :site, identifier: 'test', hostname: site.hostname, path: '/en' }

      it { expect(different_path_site).to be_valid }
    end
  end

  describe 'automatic identifier assignment' do
    let(:site_without_identifier) { build :site, identifier: nil, hostname: 'my-site.host' }

    before { site_without_identifier.valid? }

    it { expect(site_without_identifier.identifier).to eq 'my-site-host' }
  end

  describe 'automatic hostname assignment' do
    let(:site_without_hostname) { build :site, identifier: 'test-site', hostname: nil }

    before { site_without_hostname.valid? }

    it { expect(site_without_hostname.hostname).to eq 'test-site' }
  end

  describe 'automatic label assignment' do
    let(:site_without_label) { build :site, identifier: 'test', hostname: 'my-site.host', label: nil }

    before { site_without_label.valid? }

    it { expect(site_without_label.label).to eq 'Test' }
  end

  describe 'path cleaning' do
    context 'with extra slashes' do
      let!(:new_site) { create :site, identifier: 'test_a', hostname: 'test.host', path: '/en///test//' }

      it { expect(new_site.path).to eq '/en/test' }
    end

    context 'with root path' do
      let!(:new_site) { create :site, identifier: 'test_b', hostname: 'my-site.host', path: '/' }

      it { expect(new_site.path).to be_nil }
    end
  end

  describe '.find_site' do
    it { expect(Comfy::Cms::Site.find_site(site.hostname)).to eq site }
    it { expect(Comfy::Cms::Site.find_site(site.hostname, '/some/path')).to eq site }

    context 'with multiple sites on same hostname' do
      let!(:site_en) { create :site, identifier: 'test_en', hostname: 'test2.host', path: 'en' }
      let!(:site_fr) { create :site, identifier: 'test_fr', hostname: 'test2.host', path: 'fr' }

      it { expect(Comfy::Cms::Site.find_site('test2.host')).to be_nil }
      it { expect(Comfy::Cms::Site.find_site('test2.host', '/en')).to eq site_en }
      it { expect(Comfy::Cms::Site.find_site('test2.host', '/fr')).to eq site_fr }
      it { expect(Comfy::Cms::Site.find_site('test2.host', '/en/some/path')).to eq site_en }
    end
  end

  describe '.find_site with hostname aliases' do
    let!(:site_b) { create :site, identifier: 'site_b', hostname: 'test2.host' }

    before do
      ComfortableMexicanSofa.config.hostname_aliases = {
        site.hostname => 'alias_a.host',
        'test2.host'  => %w[alias_b.host alias_c.host]
      }
    end

    it { expect(Comfy::Cms::Site.find_site('alias_a.host')).to eq site }
    it { expect(Comfy::Cms::Site.find_site('alias_b.host')).to eq site_b }
    it { expect(Comfy::Cms::Site.find_site('alias_c.host')).to eq site_b }
  end

  describe '#url' do
    it { expect(site.url).to eq "//#{site.hostname}" }
    it { expect(site.url(relative: true)).to be_nil }

    context 'with site path' do
      before { site.update_column(:path, '/site-path') }

      it { expect(site.url).to eq "//#{site.hostname}/site-path" }
      it { expect(site.url(relative: true)).to eq '/site-path' }
    end

    context 'with public_cms_path configured' do
      before do
        site.update_column(:path, '/site-path')
        ComfortableMexicanSofa.config.public_cms_path = 'cms'
      end

      it { expect(site.url).to eq "//#{site.hostname}/cms/site-path" }
    end
  end

  describe 'cascading destroy' do
    let!(:layout) { create :layout, site: site }
    let!(:page) { create :page, site: site, layout: layout }
    let!(:snippet) { create :snippet, site: site }
    let!(:category) { create :category, site: site }

    it { expect { site.destroy }.to change { Comfy::Cms::Layout.count }.by(-1) }
    it { expect { site.destroy }.to change { Comfy::Cms::Page.count }.by(-1) }
    it { expect { site.destroy }.to change { Comfy::Cms::Snippet.count }.by(-1) }
    it { expect { site.destroy }.to change { Comfy::Cms::Category.count }.by(-1) }
  end
end
