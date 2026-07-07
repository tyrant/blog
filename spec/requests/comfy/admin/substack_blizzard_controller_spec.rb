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
      { 'uid' => 'u0', 'text' => 'stale group text', 'body_json' => { 'type' => 'doc' },
        'notes' => [{ 'url' => 'https://substack.com/profile/4619740-mikey-clarke/note/c-111', 'timestamp' => 90.days.ago.iso8601 }] }
    ] }
  end

  before { reset_cms_config }

  describe 'GET index' do
    before { get comfy_admin_substack_blizzard_path(days: 14), headers: http_auth_headers }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'stale group text' }
    it { expect(response.body).to include 'copy-blizzard-text' }
    it { expect(response.body).to include 'search post titles' }
    it { expect(response.body).to include 'href="https://substack.com/profile/4619740-mikey-clarke/note/c-111"' }

    it 'mounts the forecast calendar' do
      expect(response.body).to include "data-controller='blizzard-forecast'"
    end

    it 'shows the totals panel' do
      expect(response.body).to include 'Totals'
      expect(response.body).to include 'blizzard entries'
    end

    it 'seeds the calendar with the group forecast payload' do
      expect(response.body).to include 'blizzard-forecast-groups-value'
    end

    it 'seeds the saved-schedule value for client-side render on load' do
      expect(response.body).to include 'blizzard-forecast-saved-value'
    end

    it 'provides the save-forecasts endpoint url' do
      expect(response.body).to include 'blizzard-forecast-save-url-value'
    end

    context 'the forecast ignores the due-list filters' do
      let!(:blog_post) { create :post, site: site, layout: layout, title: 'Findable Post' }
      before { get comfy_admin_substack_blizzard_path(days: 14, q: 'nope'), headers: http_auth_headers }

      it 'still carries every group into the calendar payload even when filtered out of the due list' do
        expect(response.body).to include 'stale group text'
      end
    end

    context 'days=0 is accepted' do
      before { get comfy_admin_substack_blizzard_path(days: 0), headers: http_auth_headers }
      it { expect(response).to have_http_status :success }
      it { expect(response.body).to include 'stale group text' }
    end

    context 'q filters by post title' do
      let!(:blog_post) { create :post, site: site, layout: layout, title: 'Findable Post' }

      context 'matching title' do
        before { get comfy_admin_substack_blizzard_path(days: 14, q: 'findable'), headers: http_auth_headers }
        it { expect(response.body).to include 'stale group text' }
      end

      context 'non-matching title' do
        before { get comfy_admin_substack_blizzard_path(days: 14, q: 'nope'), headers: http_auth_headers }
        # The group is filtered out of the due list; it still appears in the
        # (filter-independent) forecast payload, so assert on the due list itself.
        it { expect(response.body).to include 'No text groups have' }
      end
    end

    context 'a post with multiple stale groups lists its title only once' do
      let!(:blog_post) { create :post, site: site, layout: layout, title: 'Just Once Post' }
      let(:data) do
        { 'blizzard' => [
          { 'text' => 'group one', 'body_json' => {}, 'notes' => [{ 'url' => 'u1', 'timestamp' => 90.days.ago.iso8601 }] },
          { 'text' => 'group two', 'body_json' => {}, 'notes' => [{ 'url' => 'u2', 'timestamp' => 80.days.ago.iso8601 }] }
        ] }
      end

      # Rendered link text appears once in the due list; the title also appears
      # in the forecast payload (one per group), so scope the count to the link.
      it { expect(response.body.scan('>Just Once Post<').size).to eq 1 }
      it { expect(response.body).to include 'group one' }
      it { expect(response.body).to include 'group two' }
    end

    context 'pagination at 20 per page' do
      let(:data) do
        { 'blizzard' => (0..20).map { |n| { 'text' => "blizz group #{n}", 'body_json' => {}, 'notes' => [{ 'url' => "u#{n}", 'timestamp' => (100 - n).days.ago.iso8601 }] } } }
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

  describe 'scheduled posting API (local task)' do
    let(:due_t) { 1.hour.ago.utc.iso8601 }
    let(:new_url) { 'https://substack.com/profile/4619740-mikey-clarke/note/c-333' }

    before do
      BlizzardScheduleConfig.instance.update!(schedule: {
        'days' => 7, 'even' => true, 'shuffle' => true,
        'events' => [
          { 'c' => categorization.id, 'u' => 'u0', 't' => due_t },
          { 'c' => categorization.id, 'u' => 'u0', 't' => 10.days.from_now.utc.iso8601 }
        ]
      })
    end

    describe 'POST scheduled/claim.json' do
      before { post comfy_admin_substack_blizzard_claim_scheduled_path(format: :json), params: { limit: 5 }, headers: http_auth_headers }

      it { expect(response).to have_http_status :success }
      it { expect(response.parsed_body.size).to eq 1 }
      it { expect(response.parsed_body.first['body_json']).to eq({ 'type' => 'doc' }) }
      it { expect(response.parsed_body.first['post_url']).to eq categorization.url }
      it { expect(BlizzardScheduleConfig.instance.schedule['events'].first['claimed_at']).to be_present }
      it { expect(BlizzardScheduleConfig.instance.schedule['events'].last['claimed_at']).to be_nil }
    end

    describe 'GET scheduled-due.json (dry run, no claiming)' do
      before { get comfy_admin_substack_blizzard_scheduled_due_path(format: :json), headers: http_auth_headers }

      it { expect(response.parsed_body.size).to eq 1 }
      it { expect(BlizzardScheduleConfig.instance.schedule['events'].first['claimed_at']).to be_nil }
    end

    describe 'POST scheduled/confirm.json' do
      before do
        post comfy_admin_substack_blizzard_confirm_scheduled_path(format: :json),
             params: { categorization_id: categorization.id, uid: 'u0', t: due_t, url: new_url, timestamp: '2026-07-04T00:00:00Z' },
             headers: http_auth_headers
      end

      it { expect(response.parsed_body['ok']).to be true }
      it { expect(categorization.reload.data['blizzard'][0]['notes'].map { |n| n['url'] }).to include new_url }
      it { expect(BlizzardScheduleConfig.instance.schedule['events'].first['posted_at']).to be_present }

      it 'is idempotent — a repeat confirm does not double-append' do
        post comfy_admin_substack_blizzard_confirm_scheduled_path(format: :json),
             params: { categorization_id: categorization.id, uid: 'u0', t: due_t, url: new_url, timestamp: '2026-07-04T00:00:00Z' },
             headers: http_auth_headers
        expect(categorization.reload.data['blizzard'][0]['notes'].count { |n| n['url'] == new_url }).to eq 1
      end
    end
  end

  describe 'POST add_note.json (local repost task API)' do
    before do
      post comfy_admin_substack_blizzard_add_note_path(format: :json),
           params: { categorization_id: categorization.id, uid: 'u0',
                     url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', timestamp: '2026-06-22T00:00:00Z' },
           headers: http_auth_headers
    end

    it { expect(response).to have_http_status :success }
    it { expect(JSON.parse(response.body)['success']).to be true }
    it { expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 2 }

    context 'invalid (missing url) returns 422' do
      before do
        post comfy_admin_substack_blizzard_add_note_path(format: :json),
             params: { categorization_id: categorization.id, uid: 'u0', url: '', timestamp: '2026-06-22T00:00:00Z' },
             headers: http_auth_headers
      end
      it { expect(response).to have_http_status :unprocessable_entity }
      it { expect(JSON.parse(response.body)['success']).to be false }
    end
  end

  describe 'POST reseed' do
    let(:rich_body) { { 'type' => 'doc', 'content' => [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'reseeded' }] }] } }

    before do
      SubstackSyncConfig.instance.update!(session_cookie: 'sess')
      stub_request(:get, 'https://substack.com/api/v1/reader/comment/999')
        .to_return(status: 200, body: { 'comment' => { 'body_json' => rich_body } }.to_json)
      post comfy_admin_substack_blizzard_reseed_path,
           params: { categorization_id: categorization.id, uid: 'u0',
                     note_url: 'https://substack.com/@mikeyclarke/note/c-999', days: 14, page: 2 },
           headers: http_auth_headers
    end

    it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14, page: 2) }
    it { expect(categorization.reload.data['blizzard'][0]['text']).to start_with 'reseeded' }

    context 'fetch fails' do
      let(:rich_body) { {} }
      it { expect(flash[:danger]).to be_present }
    end
  end

  describe 'POST add_note (manual paste-back)' do
    context 'with url and timestamp' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0',
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', timestamp: '2026-06-19T00:00:00Z', days: 14 },
             headers: http_auth_headers
      end

      it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14) }
      it { expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 2 }
    end

    context 'retains the page number on redirect' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0',
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', timestamp: '2026-06-19T00:00:00Z', days: 14, page: 3 },
             headers: http_auth_headers
      end

      it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14, page: 3) }
    end

    context 'human-friendly timestamp is converted to ISO' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0',
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', timestamp: '21 Jun 2025 at 19:00', days: 14 },
             headers: http_auth_headers
      end

      it { expect(categorization.reload.data['blizzard'][0]['notes'].last['timestamp']).to eq '2025-06-21T07:00:00Z' }
    end

    context 'unparseable timestamp is rejected' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0', url: 'u', timestamp: 'gibberish', days: 14 },
             headers: http_auth_headers
      end

      it { expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 1 }
      it { expect(flash[:danger]).to be_present }
    end

    context 'missing fields' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0', url: '', timestamp: '', days: 14 },
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
           params: { categorization_id: categorization.id, uid: 'u0', days: 14 },
           headers: http_auth_headers
    end

    it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14) }
    it { expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 2 }
    it { expect(categorization.reload.data['blizzard'][0]['notes'].last['url']).to eq 'https://substack.com/profile/4619740-mikey-clarke/note/c-999' }

    context 'API failure surfaces as a flash, no append' do
      before do
        stub_request(:post, 'https://substack.com/api/v1/comment/feed').to_return(status: 500, body: 'boom')
        post comfy_admin_substack_blizzard_create_note_path,
             params: { categorization_id: categorization.id, uid: 'u0', days: 14 },
             headers: http_auth_headers
      end
      it { expect(flash[:danger]).to be_present }
    end
  end

  describe 'POST save_schedule' do
    let(:payload) do
      { days: 7, even: true, shuffle: false, groupsDigest: 'abc123',
        events: [{ c: categorization.id, u: 'u0', t: '2026-07-05T09:00:00.000Z' }] }
    end

    before do
      post comfy_admin_substack_blizzard_schedule_path,
           params: payload.to_json,
           headers: http_auth_headers.merge('CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json')
    end

    it { expect(response).to have_http_status :success }
    it { expect(response.parsed_body['ok']).to be true }

    it 'persists the events' do
      expect(BlizzardScheduleConfig.instance.schedule['events'].size).to eq 1
    end

    it 'persists the interval' do
      expect(BlizzardScheduleConfig.instance.schedule['days']).to eq 7
    end

    it 'persists the even-spread flag' do
      expect(BlizzardScheduleConfig.instance.schedule['even']).to be true
    end

    it 'persists the groups digest for the re-save banner' do
      expect(BlizzardScheduleConfig.instance.schedule['groupsDigest']).to eq 'abc123'
    end

    context 'a non-object json body' do
      let(:payload) { 'just a string' }
      it { expect(response).to have_http_status :unprocessable_content }
    end
  end

  describe 'POST backfill_all' do
    before do
      allow(BackfillAllJob).to receive(:perform_later)
      post comfy_admin_substack_blizzard_backfill_all_path, headers: http_auth_headers
    end

    it { expect(BackfillAllJob).to have_received(:perform_later) }
    it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14) }
    it { expect(flash[:success]).to be_present }
  end

  describe 'POST refresh_likes' do
    before do
      allow(RefreshNoteLikesJob).to receive(:perform_later)
      post comfy_admin_substack_blizzard_refresh_likes_path, headers: http_auth_headers
    end

    it { expect(RefreshNoteLikesJob).to have_received(:perform_later) }
    it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14) }
    it { expect(flash[:success]).to be_present }
  end

  describe 'POST backfill_post' do
    context 'for a post with a Substack categorization' do
      before do
        allow(BackfillPostJob).to receive(:perform_later)
        post comfy_admin_substack_blizzard_backfill_post_path, params: { post_id: blog_post.id }, headers: http_auth_headers
      end

      it { expect(BackfillPostJob).to have_received(:perform_later).with(categorization.id) }
      it { expect(flash[:success]).to be_present }
    end

    context 'for a post with no Substack categorization' do
      let!(:bare_post) { create :post, site: site, layout: layout, title: 'No notes here' }
      before do
        allow(BackfillPostJob).to receive(:perform_later)
        post comfy_admin_substack_blizzard_backfill_post_path, params: { post_id: bare_post.id }, headers: http_auth_headers
      end

      it { expect(BackfillPostJob).to_not have_received(:perform_later) }
      it { expect(flash[:danger]).to be_present }
    end
  end
end
