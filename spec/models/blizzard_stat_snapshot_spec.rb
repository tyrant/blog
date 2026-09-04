# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlizzardStatSnapshot do

  let!(:site) { create :site }
  let!(:post) { create :post, site: site }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) do
    create :categorization, category: category, categorized: post, data: {
      'blizzard' => [
        { 'uid' => 'e0', 'notes' => [{ 'url' => 'u1' }, { 'url' => 'u2' }] },
        { 'uid' => 'e1', 'notes' => [{ 'url' => 'u3' }] }
      ]
    }
  end

  describe '.current_totals' do
    subject(:totals) { described_class.current_totals }

    it { expect(totals[:posts]).to eq Comfy::Blog::Post.count }
    it { expect(totals[:entries]).to eq 2 }
    it { expect(totals[:notes]).to eq 3 }

    context 'non-Substack categorizations are ignored' do
      let!(:other_cat) { create :category, site: site, label: 'Whimsy' }
      let!(:other) { create :categorization, category: other_cat, categorized: post, data: { 'blizzard' => [{ 'uid' => 'x', 'notes' => [{ 'url' => 'z' }] }] } }
      it { expect(described_class.current_totals[:entries]).to eq 2 }
    end

    context 'the unattached-notes pool has entries too' do
      before { BlizzardScheduleConfig.instance.update!(data: { 'blizzard' => [{ 'uid' => 'u0', 'notes' => [{ 'url' => 'u4' }] }] }) }

      it { expect(described_class.current_totals[:entries]).to eq 3 }
      it { expect(described_class.current_totals[:notes]).to eq 4 }
    end
  end

  describe '.record!' do
    it { expect { described_class.record! }.to change(described_class, :count).by(1) }
    it { expect(described_class.record!.entries).to eq 2 }
    it { expect(described_class.record!.notes).to eq 3 }
    it { expect(described_class.record!.captured_at).to be_present }
  end
end
