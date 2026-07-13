# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TopicalCategoryRetirer do
  let(:site) { create :site }

  def category_for(label)
    create :category, label: label, categorized_type: 'Comfy::Blog::Post', site: site
  end

  def tag_post(post, tag)
    BlogPostTag.without_mirror { post.tags << tag }
  end

  context 'when a category and its tag are in exact parity' do
    let(:post) { create :post, site: site }
    let!(:category) { category_for('Whimsy') }
    let!(:categorization) { create :categorization, category: category, categorized: post }
    let!(:tag) { Tag.create!(name: 'Whimsy').tap { |t| tag_post(post, t) } }

    it 'deletes the category' do
      expect { described_class.execute(labels: ['Whimsy']) }.to change(Comfy::Cms::Category, :count).by(-1)
    end

    it 'cascade-deletes its categorizations' do
      expect { described_class.execute(labels: ['Whimsy']) }.to change(Comfy::Cms::Categorization, :count).by(-1)
    end

    it 'leaves the tag and its links intact' do
      described_class.execute(labels: ['Whimsy'])
      expect(tag.reload.posts).to contain_exactly(post)
    end

    it 'reports the deletion' do
      expect(described_class.execute(labels: ['Whimsy']).deleted).to eq ['Whimsy']
    end
  end

  context 'when the category has drifted from its tag' do
    let(:post) { create :post, site: site }
    let!(:category) { category_for('NSFW') }
    let!(:categorization) { create :categorization, category: category, categorized: post }
    let!(:tag) { Tag.create!(name: 'NSFW') } # tag has no link — not in parity

    it 'does not delete the category' do
      expect { described_class.execute(labels: ['NSFW']) }.to_not change(Comfy::Cms::Category, :count)
    end

    it 'reports it skipped' do
      expect(described_class.execute(labels: ['NSFW']).skipped).to eq ['NSFW']
    end
  end

  context 'when the category is already gone' do
    it 'skips silently' do
      result = described_class.execute(labels: ['Whimsy'])
      expect(result.deleted).to be_empty
    end
  end
end
