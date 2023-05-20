require 'rails_helper'

describe ComfyBlogPostMethods do

  let!(:site)   { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:vba)    { Comfy::Cms::Category.find_by label: 'Very Bad Advice' }
  let!(:whimsy) { Comfy::Cms::Category.find_by label: 'Whimsy' }
  let!(:nsfw)   { Comfy::Cms::Category.find_by label: 'NSFW' }

  describe '#nsfw?' do

    let!(:post) { create :post, site: site, layout: layout }

    context 'post without an NSFW categorization' do
      it { expect(post.nsfw?).to eq false }
    end

    context 'post with an NSFW categorization' do
      let!(:cat) { create :categorization, category: nsfw, categorized: post }
      it { expect(post.nsfw?).to eq true }
    end
  end

  describe '#prev_nek' do


    # Six posts, a smattering of categorizations.
    let!(:post1) { create :post, site: site, layout: layout, published_at: DateTime.now - 8.days }
    let!(:post2) { create :post, site: site, layout: layout, published_at: DateTime.now - 7.days }
    let!(:post3) { create :post, site: site, layout: layout, published_at: DateTime.now - 6.days }
    let!(:post4) { create :post, site: site, layout: layout, published_at: DateTime.now - 5.days }
    let!(:post5) { create :post, site: site, layout: layout, published_at: DateTime.now - 4.days }
    let!(:post6) { create :post, site: site, layout: layout, published_at: DateTime.now - 3.days }
    # VBA: odds
    let!(:c1) { create :categorization, category: vba, categorized: post1 }
    let!(:c2) { create :categorization, category: vba, categorized: post3 }
    let!(:c3) { create :categorization, category: vba, categorized: post5 }
    # Whimsy: evens
    let!(:c4) { create :categorization, category: whimsy, categorized: post2 }
    let!(:c5) { create :categorization, category: whimsy, categorized: post4 }
    let!(:c6) { create :categorization, category: whimsy, categorized: post6 }
    # Raunch: middle two. We want to return posts 3,4 ONLY if nsfw is truthy.
    # Otherwise they should never appear in prev/nek.
    let!(:c7) { create :categorization, category: nsfw, categorized: post3 } 
    let!(:c8) { create :categorization, category: nsfw, categorized: post4 }

    describe 'No category filtering' do

      describe "querying post1" do
        it { expect(post1.prev).to eq nil }
        it { expect(post1.nek).to eq post2 }
      end

      describe "querying post3" do
        it { expect(post3.prev).to eq post2 }
        it { expect(post3.nek).to eq post5 }
      end

      describe "querying post6" do
        it { expect(post6.prev).to eq post5 }
        it { expect(post6.nek). to eq nil }
      end
    end

    describe 'Category filtering' do
      describe "filtering just VBA" do
        describe "querying post1" do
          it { expect(post1.prev(category: vba)).to eq nil }
          it { expect(post1.nek(category: vba)).to eq post5 }
        end

        describe "querying post2" do
          it { expect(post2.prev(category: vba)).to eq post1 }
          it { expect(post2.nek(category: vba)).to eq post5 }
        end

        describe "querying post3" do
          it { expect(post3.prev(category: vba)).to eq post1 }
          it { expect(post3.nek(category: vba)).to eq post5 }
        end

        describe "querying post4" do
          it { expect(post4.prev(category: vba)).to eq post1 }
          it { expect(post4.nek(category: vba)).to eq post5 }
        end

        describe "querying post5" do
          it { expect(post5.prev(category: vba)).to eq post1 }
          it { expect(post5.nek(category: vba)).to eq nil }
        end

        describe "querying post6" do
          it { expect(post6.prev(category: vba)).to eq post5 }
          it { expect(post6.nek(category: vba)).to eq nil }
        end
      end

      describe "filtering just Whimsy" do
        describe "querying post1" do
          it { expect(post1.prev(category: whimsy)).to eq nil }
          it { expect(post1.nek(category: whimsy)).to eq post2 }
        end

        describe "querying post2" do
          it { expect(post2.prev(category: whimsy)).to eq nil }
          it { expect(post2.nek(category: whimsy)).to eq post6 }
        end

        describe "querying post3" do
          it { expect(post3.prev(category: whimsy)).to eq post2 }
          it { expect(post3.nek(category: whimsy)).to eq post6 }
        end

        describe "querying post4" do
          it { expect(post4.prev(category: whimsy)).to eq post2 }
          it { expect(post4.nek(category: whimsy)).to eq post6 }
        end

        describe "querying post5" do
          it { expect(post5.prev(category: whimsy)).to eq post2 }
          it { expect(post5.nek(category: whimsy)).to eq post6 }
        end

        describe "querying post6" do
          it { expect(post6.prev(category: whimsy)).to eq post2 }
          it { expect(post6.nek(category: whimsy)).to eq nil }
        end
      end

      describe "NSFW filter: naughty posts appear only when whitelisted" do
        describe "querying post2 with nsfw filter absent" do
          it { expect(post2.prev(category: vba)).to eq post1 }
          it { expect(post2.nek(category: vba)).to eq post5 }
        end

        describe "querying post2 with nsfw filter manually false" do
          it { expect(post2.prev(category: vba, nsfw: false)).to eq post1 }
          it { expect(post2.nek(category: vba, nsfw: false)).to eq post5 }
        end

        describe "querying post2 with nsfw filter manually true" do
          it { expect(post2.prev(category: vba, nsfw: true)).to eq post1 }
          it { expect(post2.nek(category: vba, nsfw: true)).to eq post3 }
        end

        describe "querying post2 with category absent and nsfw absent" do
          it { expect(post2.prev).to eq post1 }
          it { expect(post2.nek).to eq post5 }
        end

        describe "querying post2 with category absent and nsfw false" do
          it { expect(post2.prev(nsfw: false)).to eq post1 }
          it { expect(post2.nek(nsfw: false)).to eq post5 }
        end

        describe "querying post1 with category absent and nsfw true" do
          it { expect(post1.prev(nsfw: true)).to eq nil }
          it { expect(post1.nek(nsfw: true)).to eq post2 }
        end

        describe "querying post2 with category absent and nsfw true" do
          it { expect(post2.prev(nsfw: true)).to eq post1 }
          it { expect(post2.nek(nsfw: true)).to eq post3 }
        end

        describe "querying post3 with category absent and nsfw true" do
          it { expect(post3.prev(nsfw: true)).to eq post2 }
          it { expect(post3.nek(nsfw: true)).to eq post4 }
        end

        describe "querying post4 with category absent and nsfw true" do
          it { expect(post4.prev(nsfw: true)).to eq post3 }
          it { expect(post4.nek(nsfw: true)).to eq post5 }
        end

        describe "querying post5 with category absent and nsfw true" do
          it { expect(post5.prev(nsfw: true)).to eq post4 }
          it { expect(post5.nek(nsfw: true)).to eq post6 }
        end

        describe "querying post6 with category absent and nsfw true" do
          it { expect(post6.prev(nsfw: true)).to eq post5 }
          it { expect(post6.nek(nsfw: true)).to eq nil }
        end
      end

      describe "Filtering"
    end
  end
end