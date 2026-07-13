# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategoryTagMigrator do
  let(:site) { create :site }

  def categorize(label, post)
    category = Comfy::Cms::Category.find_or_create_by!(label: label, categorized_type: 'Comfy::Blog::Post', site: site)
    create :categorization, category: category, categorized: post
  end

  it 'creates a tag per label and links its posts' do
    post = create :post, site: site
    categorize('Whimsy', post)
    described_class.execute
    expect(post.reload.tags.map(&:name)).to include('Whimsy')
  end

  it 'reuses an imported substack tag with the same name (case-insensitive)' do
    Tag.create!(name: 'whimsy', substack_tag_id: 'uuid-w')
    post = create :post, site: site
    categorize('Whimsy', post)
    expect { described_class.execute }.to_not change(Tag, :count)
  end

  it 'does not mirror the migration back to substack' do
    allow(Substack::TagMirror).to receive(:assign)
    post = create :post, site: site
    categorize('Whimsy', post)
    described_class.execute
    expect(Substack::TagMirror).to_not have_received(:assign)
  end

  it 'skips absent categories' do
    expect { described_class.execute(labels: ['Nonexistent']) }.to_not change(BlogPostTag, :count)
  end
end
