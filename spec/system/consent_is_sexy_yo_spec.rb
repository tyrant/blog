# frozen_string_literal: true

require 'rails_helper'

shared_examples 'Naughty posts CSS-hidden' do |wait|
  before { sleep 1 if wait }
  it { expect(all('.post:not(.hidden)').length).to eq general_posts.length }
end

shared_examples 'Naughty posts CSS-showing' do |wait|
  before { sleep 1 if wait }
  it { expect(all('.post:not(.hidden)').length).to eq (nsfw_posts.length + general_posts.length) }
end

shared_examples 'Webkit blur effect disappears on hover' do |wait|
  before { sleep 1 if wait }
  it { expect { find("[data-post-nsfw-value=\'true\']", match: :first).hover }
         .to change { webkit_blur_pixels }
         .from('blur(4px)')
         .to('none') }
end

shared_examples "Webkit blur effect unaffected by hover" do |wait|
  before { sleep 1 if wait }
  it { expect { find("[data-post-nsfw-value=\'true\']", match: :first).hover }
         .not_to change { webkit_blur_pixels } }
end

shared_examples "Webkit blur effect remains on hover" do
  before { find("[data-post-nsfw-value=\'true\']", match: :first).hover }
  it { expect(webkit_blur_pixels).to eq 'blur(4px)' }
end

shared_examples "Webkit blur effect absent on hover" do |wait|
  before { sleep 1 if wait
           find("[data-post-nsfw-value=\'true\']", match: :first).hover }
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

describe 'ConsentIsSexy component usage', type: :system, js: true do
  let!(:site) { Comfy::Cms::Site.find_by(identifier: 'blog') || create(:site, identifier: 'blog', hostname: 'localhost', path: '/', label: 'Blog Site') }
  let!(:layout) { site.layouts.first || create(:layout, site: site, identifier: 'default', label: 'Default Layout', content: '<html><body>{{ cms:page:content }}</body></html>') }
  
  let!(:nsfw_category) { create(:category, site: site, label: 'NSFW') }
  let!(:general_category) { create(:category, site: site, label: 'General') }
  
  let!(:nsfw_posts) do
    (1..6).map do |i|
      post = create(:post, site: site, layout: layout, published_at: i.days.ago, is_published: true)
      post.update!(title: "NSFW Post #{i}", slug: "nsfw-post-#{i}")
      create(:categorization, categorized: post, category: nsfw_category)
      post
    end
  end
  
  let!(:general_posts) do
    (1..6).map do |i|
      post = create(:post, site: site, layout: layout, published_at: (i + 6).days.ago, is_published: true)
      post.update!(title: "General Post #{i}", slug: "general-post-#{i}")
      create(:categorization, categorized: post, category: general_category)
      post
    end
  end

  before do
    # Mock ComfyBlog configuration for consistent pagination
    allow(ComfyBlog.config).to receive(:posts_per_page).and_return(12)
    
    # Ensure the site is set as the default CMS site
    allow(Comfy::Cms::Site).to receive(:find_site).and_return(site)
    allow(Comfy::Cms::Site).to receive(:first).and_return(site)
    
    # Mock the CMS site detection that happens in the parent controller
    allow_any_instance_of(PostsController).to receive(:load_cms_site) do |controller|
      controller.instance_variable_set(:@cms_site, site)
    end
    
    # Mock CMS methods to avoid rendering issues with unprocessed CMS tags
    allow_any_instance_of(Comfy::Blog::Post).to receive(:resized_blob_or_orig_or_placeholder_url).and_return('http://picsum.photos/512/512')
    allow_any_instance_of(Comfy::Blog::Post).to receive(:content_cache).and_return('<p>Test content</p>')
    allow_any_instance_of(Comfy::Blog::Post).to receive(:render).and_return('<p>Test content</p>')
  end

  describe 'setting and saving NSFW option values' do

    # Normally we'd just use a `let`, but `let`s cache their values. We don't
    # want that. We want this to execute in full each time it's called.
    def webkit_blur_pixels
      lol = <<~LOL
        (() => {
          const css = "[data-post-nsfw-value='true'] > div > a.link";
          const link = document.querySelector(css);
          return getComputedStyle(link).webkitFilter;
        })();
      LOL
      evaluate_script(lol)
    end

    # We don't want to use our nsfw_banished scope! Not here at least. We want
    # to paginate (exactly 12 records), then filter out its nsfw, in that order.
    let(:posts_count_page_1_without_nsfw) {
      # Use the known count of general posts since we control the test data
      general_posts.length
    }

    # Reminder: the default NSFW checkbox values are defined at
    # ApplicationController::COOKIES, and it's their values that define initial
    # checkbox behaviour:
    # banish: false; unblur-on-mouseover: true; always-show: false
    before do
      # Visit the blog posts index where the consent component is rendered
      visit '/blog'
    end

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
