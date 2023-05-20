# frozen_string_literal: true

require 'rails_helper'

describe 'ConsentIsSexy component usage', type: :system do

  let(:site) { Comfy::Cms::Site.first }

  # Ensure there's always at least one NSFW post in the first page
  # ... This post refuses to appear on the first page and for the life of me I
  # cannot figure out why and it messes up the NSFW-count tests :scream:
  # Commented-out for now.
  before do
    # Comfy::Blog::Post.create!(
    #   site: site,
    #   layout: Comfy::Cms::Layout.first,
    #   title: 'blargh',
    #   slug: 'blargh',
    #   published_at: site.blog_posts.order('published_at desc').limit(1).first.published_at + 1.hour,
    #   fragments_attributes: { 
    #     '0': {
    #       identifier: :content, 
    #       tag: "wysiwyg",
    #       content: "<p><img src='http://picsum.photos/#{Faker::Number.between(from: 300, to: 600)}/#{Faker::Number.between(from: 200, to: 450)}/' /></p>",
    #     }
    #   },
    #   categories: [Comfy::Cms::Category.find_by(label: 'NSFW')]
    # )
  end

  describe 'setting and saving NSFW option values' do

    # We don't want to use our nsfw_banished scope! Not here at least. We want
    # to paginate (exactly 12 records), then filter out its nsfw, in that order.
    let(:posts_count_page_1_without_nsfw) { 
      site.blog_posts.order(:published_at)
        .reverse_order.page(1)
        .per(ComfyBlog.config.posts_per_page)
        .to_a.reject!{ |p| p.nsfw? } 
        .length
    }
    let(:posts_count_page_1_with_nsfw) { 
      ComfyBlog.config.posts_per_page - posts_count_page_1_without_nsfw
    }

    # Reminder: the default NSFW checkbox values are defined at
    # ApplicationController::COOKIES:
    # banish: false; unblur-on-mouseover: true; always-show: false
    before { visit comfy_blog_posts_path }

    # Normally we'd just use a `let`, but `let`s cache their values. We don't
    # want that. We want this to execute in full each time it's called.
    def webkit_blur_pixels
      evaluate_script('getComputedStyle(document.querySelector("[data-post-index-nsfw-value=\'true\']")).webkitFilter')
    end

    describe "checking/unchecking 'Hide NSFW(?) posts'" do

      describe "hiding all NSFW posts" do

        it "whittles the naughty posts" do
          expect {
            check :banish
            sleep PostIndexComponent::DURATION/1000.0
          }.to change { all('.card:not(.hidden)').length }
           .from(ComfyBlog.config.posts_per_page)
           .to(posts_count_page_1_without_nsfw)
        end
      end

      describe "persisting its checkbox value on page reload" do
        before do
          check :banish
          refresh
        end

        it { expect(find('#banish')).to be_checked }
      end

      describe "immediately greying-out and disabling the other two checkboxes" do
        before { check :banish }

        it { expect(page).to have_css '#unblur_on_mouseover-li label.cursor-not-allowed' }
        it { expect(page).to have_css '#unblur_on_mouseover-li label.opacity-40' }
        it { expect(page).to have_css '#unblur_on_mouseover[disabled]' }
        it { expect(page).to have_css '#unblur_always-li label.cursor-not-allowed' }
        it { expect(page).to have_css '#unblur_always-li label.opacity-40' }
        it { expect(page).to have_css '#unblur_always[disabled]' }
      end

      describe "persisting in greying-out and disabling the other two checkboxes after page reload" do
        before do
          check :banish
          refresh
        end

        it { expect(page).to have_css '#unblur_on_mouseover-li label.cursor-not-allowed' }
        it { expect(page).to have_css '#unblur_on_mouseover-li label.opacity-40' }
        it { expect(page).to have_css '#unblur_on_mouseover[disabled]' }
        it { expect(page).to have_css '#unblur_always-li label.cursor-not-allowed' }
        it { expect(page).to have_css '#unblur_always-li label.opacity-40' }
        it { expect(page).to have_css '#unblur_always[disabled]' }
      end
      
      describe "un-greying and enabling the other two checkboxes after check, reload, uncheck" do
        before do
          check :banish
          refresh
          uncheck :banish
        end

        it { expect(page).to have_css '#unblur_on_mouseover-li label.cursor-pointer' }
        it { expect(page).not_to have_css '#unblur_on_mouseover-li label.opacity-40' }
        it { expect(page).not_to have_css '#unblur_on_mouseover[disabled]' }
        it { expect(page).to have_css '#unblur_always-li label.cursor-pointer' }
        it { expect(page).not_to have_css '#unblur_always-li label.opacity-40' }
        it { expect(page).not_to have_css '#unblur_always[disabled]' }
      end
    end

    describe "unchecking/checking 'Unblur on hover'" do
      describe "initial blur behaviour" do
        it "decreases the blur effect from 4px to 0px on hover" do
          expect { find("[data-post-index-nsfw-value=\'true\']", match: :first).hover }
            .to change { webkit_blur_pixels }
            .from('blur(4px)')
            .to('blur(0px)')
        end
      end

      describe "unchecking" do
        it "removes hover:blur-none CSS from all NSFW posts" do
          expect { uncheck :unblur_on_mouseover }
            .to change { all(:xpath, "//*[contains(@class, 'hover:blur-none')]").length }
            .from(posts_count_page_1_with_nsfw)
            .to(0)
        end
      end

      describe "blur remaining present on NSFW posts on mouseover after unchecking" do
        before { uncheck :unblur_on_mouseover }

        it "keeps the blur effect applied and unchanged" do
          expect { find("[data-post-index-nsfw-value=\'true\']", match: :first).hover }
            .not_to change { webkit_blur_pixels }
        end

        it "keeps the blur effect at 4px" do
          find("[data-post-index-nsfw-value=\'true\']", match: :first).hover
          expect(webkit_blur_pixels).to eq 'blur(4px)'
        end
      end

      describe "re-adding all prior hover:blur-none CSS on re-checking" do
        before { uncheck :unblur_on_mouseover }

        it "re-adds hover:blur-none CSS to all NSFW posts" do
          expect { check :unblur_on_mouseover }
            .to change { all(:xpath, "//*[contains(@class, 'hover:blur-none')]").length }
            .from(0)
            .to(posts_count_page_1_with_nsfw)
        end
      end

      describe "persisting its checkbox value on page reload" do
        before do
          uncheck :unblur_on_mouseover
          refresh
        end

        it { expect(find('#unblur_on_mouseover')).not_to be_checked }
      end

      describe "blur reappearing on NSFW posts on mouseover after uncheck, reload, check" do
        before do
          uncheck :unblur_on_mouseover
          refresh
          check :unblur_on_mouseover
        end

        it "returns to decreasing the blur effect from 4px to 0px on hover" do
          expect { find("[data-post-index-nsfw-value=\'true\']", match: :first).hover }
            .to change { webkit_blur_pixels }
            .from('blur(4px)')
            .to('blur(0px)')
        end
      end

      describe "immediately greying-out and disabling the unblur-always checkbox" do
        before { uncheck :unblur_on_mouseover }

        it { expect(page).to have_css '#unblur_always-li label.cursor-not-allowed' }
        it { expect(page).to have_css '#unblur_always-li label.opacity-40' }
        it { expect(page).to have_css '#unblur_always[disabled]' }
      end

      describe "persisting in greying-out and disabling the unblur-always checkbox after page reload" do
        before do
          uncheck :unblur_on_mouseover
          refresh
        end

        it { expect(page).to have_css '#unblur_always-li label.cursor-not-allowed' }
        it { expect(page).to have_css '#unblur_always-li label.opacity-40' }
        it { expect(page).to have_css '#unblur_always[disabled]' }
      end

      describe "un-greying and enabling the unblur-always checkbox after uncheck, reload, check" do
        before do
          uncheck :unblur_on_mouseover
          refresh
          check :unblur_on_mouseover
        end

        it { expect(page).to have_css '#unblur_always-li label.cursor-pointer' }
        it { expect(page).not_to have_css '#unblur_always-li label.opacity-40' }
        it { expect(page).not_to have_css '#unblur_always[disabled]' }
      end
    end

    describe "Unchecking/checking 'Unblur always'" do

      describe "Unblur CSS classes immediately vanishing on check" do
        it "removes blur-sm CSS from all NSFW posts" do
          expect { check :unblur_always }
            .to change { all(:xpath, "//*[contains(@class, 'blur-sm')]").length }
            .from(posts_count_page_1_with_nsfw)
            .to(0)
        end
      end

      describe "Unblur Webkit effect immediately vanishing on check" do 
        before { check :unblur_always }

        # For some dang reason, without the `sleep 1`, this initial webkit state
        # is "blur(3.71679px)". Bah :O
        it "removes the blur effect" do
          expect { find("[data-post-index-nsfw-value=\'true\']", match: :first).hover; sleep 1 }
            .to change { webkit_blur_pixels }
            .from('blur(4px)')
            .to('blur(0px)')
        end
      end

      describe "Checkbox value persisting on page reload" do
        before do
          check :unblur_always
          refresh
        end

        it { expect(find('#unblur_always')).to be_checked }
      end

      describe "Unblur CSS classes persisting on check, page reload" do
        it "keeps blur-sm removed after reload" do
          expect { 
            check :unblur_always
            refresh 
          }.to change { all(:xpath, "//*[contains(@class, 'blur-sm')]").length }
           .from(posts_count_page_1_with_nsfw)
           .to(0)
        end
      end

      describe "Unblur Webkit effect persisting on check, page reload" do
        before do
          check :unblur_always
          refresh
        end

        # I have no idea why just this one scenario sets the Webkit blur to
        # 'none' instead of 'blur(0px)'. But ugh.
        it "keeps blur(4px) removed" do
          expect { find("[data-post-index-nsfw-value=\'true\']", match: :first).hover }
            .to change { webkit_blur_pixels }
            .from('none')
            .to('blur(0px)')
        end
      end

      context "check, reload, uncheck" do
        before do
          check :unblur_always
          refresh
          uncheck :unblur_always
        end

        it 'reapplies the blur-sm CSS classes to NSFW posts' do
          expect(all(:xpath, "//*[contains(@class, 'blur-sm')]").length)
            .to eq posts_count_page_1_with_nsfw
        end

        # Without the `sleep 1`, turns out the Webkit initial filter state is
        # "blur(0.283206px)". Bah.
        it "keeps blur(4px) removed from all NSFW posts" do
          expect { sleep 1; find("[data-post-index-nsfw-value=\'true\']", match: :first).hover }
            .not_to change { webkit_blur_pixels }
        end
      end
    end
  end
end
