# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::SubstackBlizzardController', type: :request do

  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }
  let!(:blog_post) { create :post, site: site, layout: layout }
  let!(:category) { create :category, site: site, label: 'Substack' }
  let!(:categorization) { create :categorization, category: category, categorized: blog_post, url: 'https://mikeyclarke.substack.com/p/canonical', data: data }

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

    context 'a post with multiple stale groups lists its title only once' do
      let!(:blog_post) { create :post, site: site, layout: layout, title: 'Just Once Post' }
      let(:data) do
        { 'blizzard' => [
          { 'text' => 'group one', 'body_json' => {}, 'notes' => [{ 'url' => 'u1', 'timestamp' => 90.days.ago.iso8601 }] },
          { 'text' => 'group two', 'body_json' => {}, 'notes' => [{ 'url' => 'u2', 'timestamp' => 80.days.ago.iso8601 }] }
        ] }
      end

      it { expect(response.body.scan('Just Once Post').size).to eq 1 }
      it { expect(response.body).to include 'group one' }
      it { expect(response.body).to include 'group two' }
    end

    context 'pagination at 20 per page' do
      let(:data) do
        { 'blizzard' => (0..20).map { |n| { 'text' => "blizz group #{n}", 'body_json' => {}, 'notes' => [{ 'url' => "u#{n}", 'timestamp' => 90.days.ago.iso8601 }] } } }
      end

      context 'page 1' do
        before { get comfy_admin_substack_blizzard_path(days: 14, page: 1), headers: http_auth_headers }
        it { expect(response.body).to include 'blizz group 0<' }
        it { expect(response.body).to_not include 'blizz group 20<' }
      end

      context 'page 2' do
        before { get comfy_admin_substack_blizzard_path(days: 14, page: 2), headers: http_auth_headers }
        it { expect(response.body).to include 'blizz group 20<' }
      end
    end

    context 'days is clamped to 1..60' do
      before { get comfy_admin_substack_blizzard_path(days: 999), headers: http_auth_headers }
      it { expect(response.body).to include 'older than (days)' }
    end
  end

  describe 'GET due.json (local repost task API)' do
    before { get comfy_admin_substack_blizzard_due_path(format: :json, days: 14), headers: http_auth_headers }

    it { expect(response).to have_http_status :success }
    it { expect(JSON.parse(response.body).first['body_json']).to eq({ 'type' => 'doc' }) }
    it { expect(JSON.parse(response.body).first['template_url']).to include 'c-111' }
    it { expect(JSON.parse(response.body).first['categorization_id']).to eq categorization.id }
  end

  describe 'POST add_note.json (local repost task API)' do
    before do
      post comfy_admin_substack_blizzard_add_note_path(format: :json),
           params: { categorization_id: categorization.id, index: 0,
                     url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', timestamp: '2026-06-22T00:00:00Z' },
           headers: http_auth_headers
    end

    it { expect(response).to have_http_status :success }
    it { expect(JSON.parse(response.body)['success']).to be true }
    it { expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 2 }

    context 'invalid (missing url) returns 422' do
      before do
        post comfy_admin_substack_blizzard_add_note_path(format: :json),
             params: { categorization_id: categorization.id, index: 0, url: '', timestamp: '2026-06-22T00:00:00Z' },
             headers: http_auth_headers
      end
      it { expect(response).to have_http_status :unprocessable_entity }
      it { expect(JSON.parse(response.body)['success']).to be false }
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

    context 'retains the page number on redirect' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, index: 0,
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', timestamp: '2026-06-19T00:00:00Z', days: 14, page: 3 },
             headers: http_auth_headers
      end

      it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14, page: 3) }
    end

    context 'human-friendly timestamp is converted to ISO' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, index: 0,
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', timestamp: '21 Jun 2025 at 19:00', days: 14 },
             headers: http_auth_headers
      end

      it { expect(categorization.reload.data['blizzard'][0]['notes'].last['timestamp']).to eq '2025-06-21T07:00:00Z' }
    end

    context 'unparseable timestamp is rejected' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, index: 0, url: 'u', timestamp: 'gibberish', days: 14 },
             headers: http_auth_headers
      end

      it { expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 1 }
      it { expect(flash[:danger]).to be_present }
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
