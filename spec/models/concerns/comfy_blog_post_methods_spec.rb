require 'rails_helper'

describe ComfyBlogPostMethods do

  let!(:site)   { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:sa)     { create :category, label: 'Shite Advice', site: site }
  let!(:whimsy) { create :category, label: 'Whimsy', site: site }
  let!(:nsfw)   { create :category, label: 'NSFW', site: site }

  describe '#nsfw?' do
    let!(:post) { create :post, site: site, layout: layout }

    context 'posting without an NSFW categorization' do
      it { expect(post.nsfw?).to eq false }
    end

    context 'posting with an NSFW categorization' do
      let!(:cat) { create :categorization, category: nsfw, categorized: post }
      it { expect(post.nsfw?).to eq true }
    end
  end

  describe '#prev_nek' do
    # Six posts; a smattering of categorizations.
    
    let!(:posts) { (0..5).map { |i| create :post,
                                           site: site,
                                           layout: layout,
                                           published_at: DateTime.now + (i-8).days } }

    # Shite Advice: posts 0,2,4
    let!(:sa_posts) { [0, 2, 4].each { |i| create :categorization,
                                                  category: sa,
                                                  categorized: posts[i] } }

    # Whimsy: posts 1,3,5
    let!(:whimsy_posts) { [1, 3, 5].each { |i| create :categorization,
                                                      category: whimsy,
                                                      categorized: posts[i] } }

    # Raunch: middle two. We want to return posts 2, 3 ONLY if nsfw is truthy.
    # Otherwise they should never appear in prev/nek.
    let!(:nsfw_posts) { [2, 3].each { |i| create :categorization,
                                                  category: nsfw,
                                                  categorized: posts[i] } }

    describe 'No category filtering' do
      it { expect(posts[0].prev).to eq nil }
      it { expect(posts[0].nek).to eq posts[1] }

      it { expect(posts[2].prev).to eq posts[1] }
      it { expect(posts[2].nek).to eq posts[4] } # Not 3 - NSFW posts are hidden!

      it { expect(posts[5].prev).to eq posts[4] }
      it { expect(posts[5].nek). to eq nil }
    end

    describe 'Category filtering' do
      describe "filtering just Shite Advice" do
        it { expect(posts[0].prev(category: sa)).to eq nil }
        it { expect(posts[0].nek(category: sa)).to eq posts[4] } # 4, not 2 - 2 is NSFW

        it { expect(posts[1].prev(category: sa)).to eq posts[0] }
        it { expect(posts[1].nek(category: sa)).to eq posts[4] }

        it { expect(posts[2].prev(category: sa)).to eq posts[0] }
        it { expect(posts[2].nek(category: sa)).to eq posts[4] }

        it { expect(posts[3].prev(category: sa)).to eq posts[0] }
        it { expect(posts[3].nek(category: sa)).to eq posts[4] }

        it { expect(posts[4].prev(category: sa)).to eq posts[0] }
        it { expect(posts[4].nek(category: sa)).to eq nil }

        it { expect(posts[5].prev(category: sa)).to eq posts[4] }
        it { expect(posts[5].nek(category: sa)).to eq nil }
      end

      describe "filtering just Whimsy" do
        it { expect(posts[0].prev(category: whimsy)).to eq nil }
        it { expect(posts[0].nek(category: whimsy)).to eq posts[1] }

        it { expect(posts[1].prev(category: whimsy)).to eq nil }
        it { expect(posts[1].nek(category: whimsy)).to eq posts[5] }

        it { expect(posts[2].prev(category: whimsy)).to eq posts[1] }
        it { expect(posts[2].nek(category: whimsy)).to eq posts[5] }

        it { expect(posts[3].prev(category: whimsy)).to eq posts[1] }
        it { expect(posts[3].nek(category: whimsy)).to eq posts[5] }

        it { expect(posts[4].prev(category: whimsy)).to eq posts[1] }
        it { expect(posts[4].nek(category: whimsy)).to eq posts[5] }

        it { expect(posts[5].prev(category: whimsy)).to eq posts[1] }
        it { expect(posts[5].nek(category: whimsy)).to eq nil }
      end

      describe "NSFW filter: naughty posts appear only when whitelisted" do
        describe "querying post2 with nsfw filter absent" do
          it { expect(posts[1].prev(category: sa)).to eq posts[0] }
          it { expect(posts[1].nek(category: sa)).to eq posts[4] }
        end

        describe "querying post2 with nsfw filter manually false" do
          it { expect(posts[1].prev(category: sa, nsfw: false)).to eq posts[0] }
          it { expect(posts[1].nek(category: sa, nsfw: false)).to eq posts[4] }
        end

        describe "querying post2 with nsfw filter manually true" do
          it { expect(posts[1].prev(category: sa, nsfw: true)).to eq posts[0] }
          it { expect(posts[1].nek(category: sa, nsfw: true)).to eq posts[2] }
        end

        describe "querying post2 with category absent and nsfw absent" do
          it { expect(posts[1].prev).to eq posts[0] }
          it { expect(posts[1].nek).to eq posts[4] }
        end

        describe "querying post2 with category absent and nsfw false" do
          it { expect(posts[1].prev(nsfw: false)).to eq posts[0] }
          it { expect(posts[1].nek(nsfw: false)).to eq posts[4] }
        end

        describe "querying post1 with category absent and nsfw true" do
          it { expect(posts[0].prev(nsfw: true)).to eq nil }
          it { expect(posts[0].nek(nsfw: true)).to eq posts[1] }
        end

        describe "querying post2 with category absent and nsfw true" do
          it { expect(posts[1].prev(nsfw: true)).to eq posts[0] }
          it { expect(posts[1].nek(nsfw: true)).to eq posts[2] }
        end

        describe "querying post3 with category absent and nsfw true" do
          it { expect(posts[2].prev(nsfw: true)).to eq posts[1] }
          it { expect(posts[2].nek(nsfw: true)).to eq posts[3] }
        end

        describe "querying post4 with category absent and nsfw true" do
          it { expect(posts[3].prev(nsfw: true)).to eq posts[2] }
          it { expect(posts[3].nek(nsfw: true)).to eq posts[4] }
        end

        describe "querying post5 with category absent and nsfw true" do
          it { expect(posts[4].prev(nsfw: true)).to eq posts[3] }
          it { expect(posts[4].nek(nsfw: true)).to eq posts[5] }
        end

        describe "querying post6 with category absent and nsfw true" do
          it { expect(posts[5].prev(nsfw: true)).to eq posts[4] }
          it { expect(posts[5].nek(nsfw: true)).to eq nil }
        end
      end

      describe "Filtering"
    end
  end
end