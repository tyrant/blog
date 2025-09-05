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
      it 'returns NSFW category first, then non-NSFW categories' do
        categories = Comfy::Cms::Category.nsfw_first
        expect(categories.first).to eq nsfw
        expect(categories[1..-1]).to include(shite_advice, whimsy, other)
        expect(categories[1..-1]).not_to include(nsfw) # Should not be duplicated in the rest
      end
    end

    describe '.public_names' do
      it 'returns only categories with public labels' do
        public_categories = Comfy::Cms::Category.public_names
        expect(public_categories).to include(shite_advice, whimsy, nsfw)
        expect(public_categories).not_to include(other)
      end
    end

    describe '.nsfw_banished!' do
      it 'excludes NSFW category' do
        non_nsfw = Comfy::Cms::Category.nsfw_banished!
        expect(non_nsfw).to include(shite_advice, whimsy, other)
        expect(non_nsfw).not_to include(nsfw)
      end
    end

    describe '.nsfw_banished' do
      context 'when banish is true' do
        it 'excludes NSFW category' do
          result = Comfy::Cms::Category.nsfw_banished(true)
          expect(result).to include(shite_advice, whimsy, other)
          expect(result).not_to include(nsfw)
        end
      end

      context 'when banish is false' do
        it 'includes all categories' do
          result = Comfy::Cms::Category.nsfw_banished(false)
          expect(result).to include(shite_advice, whimsy, nsfw, other)
        end
      end

      context 'when banish is nil' do
        it 'includes all categories' do
          result = Comfy::Cms::Category.nsfw_banished(nil)
          expect(result).to include(shite_advice, whimsy, nsfw, other)
        end
      end
    end
  end

  describe '#nsfw?' do
    context 'when category is NSFW' do
      it 'returns true' do
        expect(nsfw.nsfw?).to be true
      end
    end

    context 'when category is not NSFW' do
      it 'returns false for Shite Advice' do
        expect(shite_advice.nsfw?).to be false
      end

      it 'returns false for Whimsy' do
        expect(whimsy.nsfw?).to be false
      end

      it 'returns false for other categories' do
        expect(other.nsfw?).to be false
      end
    end
  end
end
