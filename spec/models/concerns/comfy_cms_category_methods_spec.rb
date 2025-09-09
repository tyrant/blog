require 'rails_helper'

RSpec.describe ComfyCmsCategoryMethods, type: :model do
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  
  # Create categories that match the expected labels
  let!(:shite_advice) { create :category, label: 'Shite Advice', site: site }
  let!(:whimsy) { create :category, label: 'Whimsy', site: site }
  let!(:nsfw) { create :category, label: 'NSFW', site: site }
  let!(:other) { create :category, label: 'Other Category', site: site }

  describe 'scopes' do
    describe '.nsfw_first' do
      describe 'returning NSFW category first, then non-NSFW categories' do
        let(:categories) { Comfy::Cms::Category.nsfw_first }
        
        it { expect(categories.first).to eq nsfw }
        it { expect(categories[1..-1]).to include(shite_advice, whimsy, other) }
        it { expect(categories[1..-1]).not_to include(nsfw) } # Should not be duplicated in the rest
      end
    end

    describe '.public_names' do
      describe 'returning only categories with public labels' do
        let(:public_categories) { Comfy::Cms::Category.public_names }

        it { expect(public_categories).to include(shite_advice, whimsy, nsfw) }
        it { expect(public_categories).not_to include(other) }
      end
    end

    describe '.nsfw_banished!' do
      describe 'excluding NSFW category' do
        let(:non_nsfw) { Comfy::Cms::Category.nsfw_banished! }
        
        it { expect(non_nsfw).to include(shite_advice, whimsy, other) }
        it { expect(non_nsfw).not_to include(nsfw) }
      end
    end

    describe '.nsfw_banished' do
      describe 'when banish is true' do
        let(:result) { Comfy::Cms::Category.nsfw_banished(true) }
        
        it { expect(result).to include(shite_advice, whimsy, other) }
        it { expect(result).not_to include(nsfw) }
      end

      describe 'when banish is false' do
        let(:result) { Comfy::Cms::Category.nsfw_banished(false) }
        
        it { expect(result).to include(shite_advice, whimsy, nsfw, other) }
      end

      describe 'when banish is nil' do
        let(:result) { Comfy::Cms::Category.nsfw_banished(nil) }
        
        it { expect(result).to include(shite_advice, whimsy, nsfw, other) }
      end
    end
  end

  describe '#nsfw?' do
    describe 'when category is NSFW' do
      it { expect(nsfw.nsfw?).to be true }
    end

    describe 'when category is not NSFW' do
      it { expect(shite_advice.nsfw?).to be false }
      it { expect(whimsy.nsfw?).to be false }
      it { expect(other.nsfw?).to be false }
    end
  end
end
