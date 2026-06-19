# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::SubstackBlizzardController', type: :request do

  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:blog_post) { create :post, site: site, layout: layout }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: blog_post, data: data }

  let(:data) do
    { 'blizzard' => [
      { 'text' => 'stale group text', 'body_json' => { 'type' => 'doc' },
        'notes' => [{ 'url' => 'https://substack.com/profile/4619740-mikey-clarke/note/c-111', 'timestamp' => 90.days.ago.iso8601 }] }
    ] }
  end

  before { reset_cms_config }

  describe 'GET index' do
    before { get comfy_admin_substack_blizzard_path(days: 14), headers: http_auth_headers }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'stale group text' }

    context 'days is clamped to 1..60' do
      before { get comfy_admin_substack_blizzard_path(days: 999), headers: http_auth_headers }
      it { expect(response.body).to include 'older than (days)' }
    end
  end

  describe 'POST add_note (manual paste-back)' do
    context 'with url and timestamp' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, index: 0,
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', timestamp: '2026-06-19T00:00:00Z', days: 14 },
             headers: http_auth_headers
      end

      it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14) }
      it { expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 2 }
    end

    context 'missing fields' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, index: 0, url: '', timestamp: '', days: 14 },
             headers: http_auth_headers
      end
      it { expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 1 }
    end
  end

  describe 'POST create_note (auto via API)' do
    before do
      SubstackSyncConfig.instance.update!(session_cookie: 'sess-abc')
      stub_request(:post, 'https://substack.com/api/v1/comment/feed')
        .to_return(status: 200, body: { 'id' => 999, 'date' => '2026-06-19T00:00:00Z' }.to_json)
      post comfy_admin_substack_blizzard_create_note_path,
           params: { categorization_id: categorization.id, index: 0, days: 14 },
           headers: http_auth_headers
    end

    it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14) }
    it { expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 2 }
    it { expect(categorization.reload.data['blizzard'][0]['notes'].last['url']).to eq 'https://substack.com/profile/4619740-mikey-clarke/note/c-999' }

    context 'API failure surfaces as a flash, no append' do
      before do
        stub_request(:post, 'https://substack.com/api/v1/comment/feed').to_return(status: 500, body: 'boom')
        post comfy_admin_substack_blizzard_create_note_path,
             params: { categorization_id: categorization.id, index: 0, days: 14 },
             headers: http_auth_headers
      end
      it { expect(flash[:danger]).to be_present }
    end
  end
end
