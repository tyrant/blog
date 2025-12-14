# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Cms::Site, type: :model do
  let!(:site) { create(:site) }

  before { reset_cms_config }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:identifier) }
    it { is_expected.to validate_presence_of(:hostname) }
    it { is_expected.to validate_uniqueness_of(:identifier) }

    context 'with invalid hostname format' do
      let(:invalid_site) { build(:site, identifier: 'test', hostname: 'http://site.host') }
      it { expect(invalid_site).not_to be_valid }
    end

    context 'with valid hostname' do
      let(:valid_site) { build(:site, identifier: 'test2', hostname: 'site.host') }
      it { expect(valid_site).to be_valid }
    end

    context 'with localhost and port' do
      let(:localhost_site) { build(:site, identifier: 'test3', hostname: 'localhost:3000') }
      it { expect(localhost_site).to be_valid }
    end
  end

  describe 'path uniqueness validation' do
    context 'when same hostname and path' do
      let(:duplicate_site) { build(:site, identifier: 'test', hostname: site.hostname, path: site.path) }
      it { expect(duplicate_site).not_to be_valid }
    end

    context 'when same hostname but different path' do
      let(:different_path_site) { build(:site, identifier: 'test', hostname: site.hostname, path: '/en') }
      it { expect(different_path_site).to be_valid }
    end
  end

  describe 'automatic identifier assignment' do
    let(:site_without_identifier) { build(:site, identifier: nil, hostname: 'my-site.host') }

    it 'assigns identifier from hostname' do
      site_without_identifier.valid?
      expect(site_without_identifier.identifier).to eq('my-site-host')
    end
  end

  describe 'automatic hostname assignment' do
    let(:site_without_hostname) { build(:site, identifier: 'test-site', hostname: nil) }

    it 'assigns hostname from identifier' do
      site_without_hostname.valid?
      expect(site_without_hostname.hostname).to eq('test-site')
    end
  end

  describe 'automatic label assignment' do
    let(:site_without_label) { build(:site, identifier: 'test', hostname: 'my-site.host', label: nil) }

    it 'assigns titleized label' do
      site_without_label.valid?
      expect(site_without_label.label).to eq('Test')
    end
  end

  describe 'path cleaning' do
    it 'removes extra slashes from path' do
      new_site = create(:site, identifier: 'test_a', hostname: 'test.host', path: '/en///test//')
      expect(new_site.path).to eq('/en/test')
    end

    it 'sets root path to nil' do
      new_site = create(:site, identifier: 'test_b', hostname: 'my-site.host', path: '/')
      expect(new_site.path).to be_nil
    end
  end

  describe '.find_site' do
    it 'finds site by hostname' do
      expect(Comfy::Cms::Site.find_site(site.hostname)).to eq(site)
    end

    it 'finds site by hostname with path' do
      expect(Comfy::Cms::Site.find_site(site.hostname, '/some/path')).to eq(site)
    end

    context 'with multiple sites on same hostname' do
      let!(:site_en) { create(:site, identifier: 'test_en', hostname: 'test2.host', path: 'en') }
      let!(:site_fr) { create(:site, identifier: 'test_fr', hostname: 'test2.host', path: 'fr') }

      it 'returns nil for hostname without path' do
        expect(Comfy::Cms::Site.find_site('test2.host')).to be_nil
      end

      it 'finds correct site by path' do
        expect(Comfy::Cms::Site.find_site('test2.host', '/en')).to eq(site_en)
        expect(Comfy::Cms::Site.find_site('test2.host', '/fr')).to eq(site_fr)
      end

      it 'finds site with nested path' do
        expect(Comfy::Cms::Site.find_site('test2.host', '/en/some/path')).to eq(site_en)
      end
    end
  end

  describe '.find_site with hostname aliases' do
    let!(:site_b) { create(:site, identifier: 'site_b', hostname: 'test2.host') }

    before do
      ComfortableMexicanSofa.config.hostname_aliases = {
        site.hostname => 'alias_a.host',
        'test2.host'  => %w[alias_b.host alias_c.host]
      }
    end

    it 'finds site by alias' do
      expect(Comfy::Cms::Site.find_site('alias_a.host')).to eq(site)
      expect(Comfy::Cms::Site.find_site('alias_b.host')).to eq(site_b)
      expect(Comfy::Cms::Site.find_site('alias_c.host')).to eq(site_b)
    end
  end

  describe '#url' do
    it 'returns protocol-relative URL' do
      expect(site.url).to eq("//#{site.hostname}")
    end

    it 'returns nil for relative URL without path' do
      expect(site.url(relative: true)).to be_nil
    end

    context 'with site path' do
      before { site.update_column(:path, '/site-path') }

      it 'includes path in URL' do
        expect(site.url).to eq("//#{site.hostname}/site-path")
      end

      it 'returns relative URL with path' do
        expect(site.url(relative: true)).to eq('/site-path')
      end
    end

    context 'with public_cms_path configured' do
      before do
        site.update_column(:path, '/site-path')
        ComfortableMexicanSofa.config.public_cms_path = 'cms'
      end

      it 'includes cms path in URL' do
        expect(site.url).to eq("//#{site.hostname}/cms/site-path")
      end
    end
  end

  describe 'cascading destroy' do
    let!(:layout) { create(:layout, site: site) }
    let!(:page) { create(:page, site: site, layout: layout) }
    let!(:snippet) { create(:snippet, site: site) }
    let!(:category) { create(:category, site: site) }

    it 'destroys associated layouts' do
      expect { site.destroy }.to change { Comfy::Cms::Layout.count }.by(-1)
    end

    it 'destroys associated pages' do
      expect { site.destroy }.to change { Comfy::Cms::Page.count }.by(-1)
    end

    it 'destroys associated snippets' do
      expect { site.destroy }.to change { Comfy::Cms::Snippet.count }.by(-1)
    end

    it 'destroys associated categories' do
      expect { site.destroy }.to change { Comfy::Cms::Category.count }.by(-1)
    end
  end
end
