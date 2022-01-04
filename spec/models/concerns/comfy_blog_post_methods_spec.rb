require 'rails_helper'

describe ComfyBlogPostMethods do

  # Boilerplate, might move these to general database_cleaner setup later
  let!(:site)   { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:vba)    { create :category, site: site, label: 'Very Bad Advice' }
  let!(:whimsy) { create :category, site: site, label: 'Whimsy' }
  let!(:nsfw)   { create :category, site: site, label: 'NSFW' }

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
    let!(:post1) { 
      create :post, site: site, layout: layout, published_at: DateTime.now - 8.days
    }
    let!(:post2) { 
      create :post, site: site, layout: layout, published_at: DateTime.now - 7.days
    }
    let!(:post3) { 
      create :post, site: site, layout: layout, published_at: DateTime.now - 6.days
    }
    let!(:post4) {
      create :post, site: site, layout: layout, published_at: DateTime.now - 5.days
    }
    let!(:post5) { 
      create :post, site: site, layout: layout, published_at: DateTime.now - 4.days
    }
    let!(:post6) {
      create :post, site: site, layout: layout, published_at: DateTime.now - 3.days
    }
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
        it "returns { prev: nil, nek: post2 }" do
          expect(post1.prev_nek).to eq({ prev: nil, nek: post2 })
        end
      end

      describe "querying post3" do
        it "returns { prev: post2, nek: post5 }" do
          expect(post3.prev_nek).to eq({ prev: post2, nek: post5 })
        end
      end

      describe "querying post6" do
        it "returns { prev: post5, nek: nil }" do
          expect(post6.prev_nek).to eq({ prev: post5, nek: nil })
        end
      end
    end

    describe 'Category filtering' do

      describe "filtering just VBA" do

        describe "querying post1" do
          it "returns { prev: nil, nek: post5 }" do
            expect(post1.prev_nek(category: vba)).to eq({ prev: nil, nek: post5 })
          end
        end

        describe "querying post2" do
          it "returns { prev: post1, nek: post5 }" do
            expect(post2.prev_nek(category: vba)).to eq({ prev: post1, nek: post5 })
          end
        end

        describe "querying post3" do
          it "returns { prev: post1, nek: post5 }" do
            expect(post3.prev_nek(category: vba)).to eq({ prev: post1, nek: post5 })
          end
        end

        describe "querying post4" do
          it "returns { prev: post1, nek: post5 }" do
            expect(post4.prev_nek(category: vba)).to eq({ prev: post1, nek: post5 })
          end
        end

        describe "querying post5" do
          it "returns { prev: post1, nek: nil }" do
            expect(post5.prev_nek(category: vba)).to eq({ prev: post1, nek: nil })
          end
        end

        describe "querying post6" do
          it "returns { prev: post5, nek: nil }" do
            expect(post6.prev_nek(category: vba)).to eq({ prev: post5, nek: nil })
          end
        end
      end

      describe "filtering just Whimsy" do

        describe "querying post1" do
          it "returns { prev: nil, nek: post2 }" do
            expect(post1.prev_nek(category: whimsy)).to eq({ prev: nil, nek: post2 })
          end
        end

        describe "querying post2" do
          it "returns { prev: nil, nek: post6 }" do
            expect(post2.prev_nek(category: whimsy)).to eq({ prev: nil, nek: post6 })
          end
        end

        describe "querying post3" do
          it "returns { prev: post2, nek: post6 }" do
            expect(post3.prev_nek(category: whimsy)).to eq({ prev: post2, nek: post6 })
          end
        end

        describe "querying post4" do
          it "returns { prev: post2, nek: post6 }" do
            expect(post4.prev_nek(category: whimsy)).to eq({ prev: post2, nek: post6 })
          end
        end

        describe "querying post5" do
          it "returns { prev: post2, nek: post6 }" do
            expect(post5.prev_nek(category: whimsy)).to eq({ prev: post2, nek: post6 })
          end
        end

        describe "querying post6" do
          it "returns { prev: post2, nek: nil }" do
            expect(post6.prev_nek(category: whimsy)).to eq({ prev: post2, nek: nil })
          end
        end
      end

      describe "NSFW filter: naughty posts appear only when whitelisted" do

        describe "querying post2 with nsfw filter absent" do
          it "returns { prev: post1, nek: post5 }" do
            expect(post2.prev_nek(category: vba))
              .to eq({ prev: post1, nek: post5 })
          end
        end

        describe "querying post2 with nsfw filter manually false" do
          it "returns { prev: post1, nek: post5 }" do
            expect(post2.prev_nek(category: vba, nsfw: false))
              .to eq({ prev: post1, nek: post5 })
          end
        end

        describe "querying post2 with nsfw filter manually true" do
          it "returns { prev: post1, nek: post5 }" do
            expect(post2.prev_nek(category: vba, nsfw: true))
              .to eq({ prev: post1, nek: post3 })
          end
        end

        describe "querying post2 with category absent and nsfw absent" do
          it "returns { prev: post1, nek: post3 }" do
            expect(post2.prev_nek)
              .to eq({ prev: post1, nek: post5 })
          end
        end

        describe "querying post2 with category absent and nsfw false" do
          it "returns { prev: post1, nek: post3 }" do
            expect(post2.prev_nek)
              .to eq({ prev: post1, nek: post5 })
          end
        end

        describe "querying post1 with category absent and nsfw true" do
          it "returns { prev: nil, nek: post2 }" do
            expect(post1.prev_nek(nsfw: true))
              .to eq({ prev: nil, nek: post2 })
          end
        end

        describe "querying post2 with category absent and nsfw true" do
          it "returns { prev: post1, nek: post3 }" do
            expect(post2.prev_nek(nsfw: true))
              .to eq({ prev: post1, nek: post3 })
          end
        end

        describe "querying post3 with category absent and nsfw true" do
          it "returns { prev: post2, nek: post4 }" do
            expect(post3.prev_nek(nsfw: true))
              .to eq({ prev: post2, nek: post4 })
          end
        end

        describe "querying post4 with category absent and nsfw true" do
          it "returns { prev: post3, nek: post5 }" do
            expect(post4.prev_nek(nsfw: true))
              .to eq({ prev: post3, nek: post5 })
          end
        end

        describe "querying post5 with category absent and nsfw true" do
          it "returns { prev: post4, nek: post6 }" do
            expect(post5.prev_nek(nsfw: true))
              .to eq({ prev: post4, nek: post6 })
          end
        end

        describe "querying post6 with category absent and nsfw true" do
          it "returns { prev: post5, nek: nil }" do
            expect(post6.prev_nek(nsfw: true))
              .to eq({ prev: post5, nek: nil })
          end
        end
      end

      describe "Filtering"
    end
  end
end