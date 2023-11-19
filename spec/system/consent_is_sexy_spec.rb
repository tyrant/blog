# frozen_string_literal: true

require 'rails_helper'

shared_examples 'Naughty posts CSS-hidden' do |wait|
  before { sleep 1 if wait }
  it { expect(all('.post-index:not(.hidden)').length).to eq posts_count_page_1_without_nsfw }
end

shared_examples 'Naughty posts CSS-showing' do |wait|
  before { sleep 1 if wait }
  it { expect(all('.post-index:not(.hidden)').length).to eq ComfyBlog.config.posts_per_page }
end

shared_examples 'Webkit blur effect disappears on hover' do |wait|
  before { sleep 1 if wait }
  it { expect { find("[data-post-index-nsfw-value=\'true\']", match: :first).hover }
         .to change { webkit_blur_pixels }
         .from('blur(4px)')
         .to('none') }
end

shared_examples "Webkit blur effect unaffected by hover" do |wait|
  before { sleep 1 if wait }
  it { expect { find("[data-post-index-nsfw-value=\'true\']", match: :first).hover }
         .not_to change { webkit_blur_pixels } }
end

shared_examples "Webkit blur effect remains on hover" do
  before { find("[data-post-index-nsfw-value=\'true\']", match: :first).hover }
  it { expect(webkit_blur_pixels).to eq 'blur(4px)' }
end

shared_examples "Webkit blur effect absent on hover" do |wait|
  before { sleep 1 if wait
           find("[data-post-index-nsfw-value=\'true\']", match: :first).hover }
  it { expect(webkit_blur_pixels).to eq 'none' }
end

shared_examples 'Unblur On Mouseover <li> disabled' do
  it { expect(page).to have_css '#unblur_on_mouseover-li label.cursor-not-allowed' }
  it { expect(page).to have_css '#unblur_on_mouseover-li label.opacity-40' }
  it { expect(page).to have_css '#unblur_on_mouseover[disabled]' }
end

shared_examples 'Unblur On Mouseover <li> enabled' do
  it { expect(page).to have_css '#unblur_on_mouseover-li label.cursor-pointer' }
  it { expect(page).not_to have_css '#unblur_on_mouseover-li label.opacity-40' }
  it { expect(page).not_to have_css '#unblur_on_mouseover[disabled]' }
end

shared_examples 'Unblur Always <li> disabled' do
  it { expect(page).to have_css '#unblur_always-li label.cursor-not-allowed' }
  it { expect(page).to have_css '#unblur_always-li label.opacity-40' }
  it { expect(page).to have_css '#unblur_always[disabled]' }
end

shared_examples 'Unblur Always <li> enabled' do
  it { expect(page).to have_css '#unblur_always-li label.cursor-pointer' }
  it { expect(page).not_to have_css '#unblur_always-li label.opacity-40' }
  it { expect(page).not_to have_css '#unblur_always[disabled]' }
end

describe 'ConsentIsSexy component usage', type: :system do

  # Ensure there's always at least one NSFW post in the first page
  # The probability of there being zero is (2/3)^12=~0.0077 ... but can't hurt
  # to be thorough. A test intermittently failing ~1% of the time is too much.
  before do
    Comfy::Cms::Categorization.find_or_create_by!(
      category: Comfy::Cms::Category.find_by(label: 'NSFW'),
      categorized: Comfy::Blog::Post.order(:updated_at).last
    )
  end

  describe 'setting and saving NSFW option values' do

    # Normally we'd just use a `let`, but `let`s cache their values. We don't
    # want that. We want this to execute in full each time it's called.
    def webkit_blur_pixels
      lol = <<~LOL
        (() => {
          const css = "[data-post-index-nsfw-value='true'] > a.link";
          const link = document.querySelector(css);
          return getComputedStyle(link).webkitFilter;
        })();
      LOL
      evaluate_script(lol)
    end

    # We don't want to use our nsfw_banished scope! Not here at least. We want
    # to paginate (exactly 12 records), then filter out its nsfw, in that order.
    let(:posts_count_page_1_without_nsfw) {
      Comfy::Cms::Site.first.blog_posts.order(:published_at)
        .reverse_order.page(1)
        .per(ComfyBlog.config.posts_per_page)
        .to_a.reject!(&:nsfw?)
        .length
    }

    # Reminder: the default NSFW checkbox values are defined at
    # ApplicationController::COOKIES, and it's their values that define initial
    # checkbox behaviour:
    # banish: false; unblur-on-mouseover: true; always-show: false
    before { visit comfy_blog_posts_path }

    describe "Checking/unchecking 'Hide NSFW(?) posts'" do
      it_behaves_like 'Naughty posts CSS-showing', false

      describe "Checking" do
        before { check :banish }
        it_behaves_like 'Naughty posts CSS-hidden', true
        it_behaves_like 'Unblur On Mouseover <li> disabled'
        it_behaves_like 'Unblur Always <li> disabled'
        
        describe 'Refreshing' do
          before { refresh }
          it { expect(find('#banish')).to be_checked }
          it_behaves_like 'Naughty posts CSS-hidden', false
          it_behaves_like 'Unblur On Mouseover <li> disabled'
          it_behaves_like 'Unblur Always <li> disabled'

          describe 'Unchecking' do
            before { uncheck :banish }
            it_behaves_like 'Naughty posts CSS-showing', true
            it_behaves_like 'Unblur On Mouseover <li> enabled'
            it_behaves_like 'Unblur Always <li> enabled'
          end
        end
      end
    end

    describe "Unchecking/checking 'Unblur on hover'" do
      it_behaves_like 'Webkit blur effect disappears on hover', false

      describe "Unchecking" do
        before { uncheck :unblur_on_mouseover }
        it_behaves_like 'Unblur Always <li> disabled'
        it_behaves_like "Webkit blur effect unaffected by hover", false
        it_behaves_like "Webkit blur effect remains on hover"

        describe "Immediately rechecking without refreshing" do
          before { check :unblur_on_mouseover }
          it_behaves_like 'Unblur Always <li> enabled'
          it_behaves_like 'Webkit blur effect disappears on hover', false
        end

        describe "Refreshing" do
          before { refresh }
          it { expect(find('#unblur_on_mouseover')).not_to be_checked }
          it_behaves_like 'Unblur Always <li> disabled'
          it_behaves_like "Webkit blur effect unaffected by hover", false
          it_behaves_like "Webkit blur effect remains on hover"

          describe "Rechecking" do
            before { check :unblur_on_mouseover }
            it_behaves_like 'Unblur Always <li> enabled'
            it_behaves_like 'Webkit blur effect disappears on hover', false
          end
        end
      end
    end

    describe "Unchecking/checking 'Unblur always'" do
      it_behaves_like 'Webkit blur effect disappears on hover', false

      describe "Checking" do
        before { check :unblur_always }
        it_behaves_like "Webkit blur effect unaffected by hover", true
        it_behaves_like "Webkit blur effect absent on hover"

        describe "Refreshing" do
          before { refresh }
          it { expect(find('#unblur_always')).to be_checked }
          it_behaves_like "Webkit blur effect unaffected by hover"
          it_behaves_like "Webkit blur effect absent on hover"

          describe "Unchecking" do
            before { uncheck :unblur_always }
            it_behaves_like 'Webkit blur effect disappears on hover', true
          end
        end
      end
    end
  end
end
