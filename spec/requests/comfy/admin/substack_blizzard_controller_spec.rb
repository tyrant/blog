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

    it 'shows the totals panel' do
      expect(response.body).to include 'Totals'
      expect(response.body).to include 'blizzard entries'
    end

    it 'shows the repost-selection settings form' do
      expect(response.body).to include 'Per-post cooldown (hours):'
    end

    it 'explains the 74/24/2 text-vs-quotation-vs-unattached split' do
      expect(response.body).to include 'random featured quotation'
      expect(response.body).to include 'href="/admin/quotations"'
      expect(response.body).to include '74%'
      expect(response.body).to include '24%'
      expect(response.body).to include 'The remaining 2%'
    end

    it 'shows the unattached-notes section with its JSON editor and backfill button' do
      expect(response.body).to include 'Unattached Notes'
      expect(response.body).to include "name='data_json_text'"
      expect(response.body).to include 'Backfill unattached Notes'
    end

    it 'shows the most-likely-to-be-suggested leaderboard' do
      expect(response.body).to include 'Most likely to be suggested next'
    end

    context 'a due group with rich formatting in its stored body_json' do
      let(:data) do
        { 'blizzard' => [
          { 'uid' => 'u0', 'text' => 'a bold quoted group', 'notes' => [],
            'body_json' => { 'type' => 'doc', 'content' => [
              { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'bold', 'marks' => [{ 'type' => 'bold' }] }] },
              { 'type' => 'blockquote', 'content' => [
                { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'quoted' }] }
              ] }
            ] } }
        ] }
      end

      it 'renders real HTML marks in the copy source, not just plain text' do
        expect(response.body).to include '<div class=\'blizzard-html\' style=\'display:none;\'><p><strong>bold</strong></p><blockquote><p>quoted</p></blockquote></div>'
      end
    end

    context 'next repost suggestion — nothing due' do
      before do
        allow(Substack::Blizzard::WeightedPicker).to receive(:execute).and_return(nil)
        get comfy_admin_substack_blizzard_path(days: 14), headers: http_auth_headers
      end

      it { expect(response.body).to include 'Nothing eligible to suggest right now.' }
    end

    context 'next repost suggestion — a text-group pick' do
      before do
        allow(Substack::Blizzard::WeightedPicker).to receive(:execute).and_return(
          { 'categorization_id' => categorization.id, 'uid' => 'u0', 'text' => 'picked text', 'body_json' => { 'type' => 'doc' } }
        )
        get comfy_admin_substack_blizzard_path(days: 14), headers: http_auth_headers
      end

      it { expect(response.body).to include 'Text group for:' }
      it { expect(response.body).to include 'picked text' }
      it { expect(response.body).to include 'Add manually' }
      it { expect(response.body).to include 'Re-seed rich text' }
      it { expect(response.body).to include 'Regenerate' }
    end

    context 'next repost suggestion — an unattached-note pick' do
      before do
        allow(Substack::Blizzard::WeightedPicker).to receive(:execute).and_return(
          { 'categorization_id' => nil, 'uid' => 'un1', 'text' => 'unattached pick', 'body_json' => { 'type' => 'doc' } }
        )
        get comfy_admin_substack_blizzard_path(days: 14), headers: http_auth_headers
      end

      it { expect(response.body).to include 'Unattached note' }
      it { expect(response.body).to include 'Add manually' }
      it { expect(response.body).to include 'Re-seed rich text' }
    end

    context 'next repost suggestion — a quotation pick' do
      let!(:quotation) { SubstackQuotation.create!(quotation: 'a quote', comment_url: 'https://x/comment/1') }

      before do
        allow(Substack::Blizzard::WeightedPicker).to receive(:execute).and_return(
          { 'categorization_id' => nil, 'uid' => nil, 'quotation_id' => quotation.id, 'text' => 'a quote', 'body_json' => { 'type' => 'doc' } }
        )
        get comfy_admin_substack_blizzard_path(days: 14), headers: http_auth_headers
      end

      it { expect(response.body).to include 'Quotation' }
      it { expect(response.body).to include 'Add manually' }
      it { expect(response.body).to include %(name="quotation_id" id="quotation_id" value="#{quotation.id}") }
    end

    it 'mounts the background-jobs progress panel' do
      expect(response.body).to include "id='job-progress'"
      expect(response.body).to include 'Background jobs'
    end

    context 'with recorded stat snapshots' do
      let!(:snapshot) { BlizzardStatSnapshot.create!(captured_at: 1.hour.ago, posts: 5, entries: 3, notes: 9) }
      before { get comfy_admin_substack_blizzard_path(days: 14), headers: http_auth_headers }

      it 'offers a Graph button opening the chart modal' do
        expect(response.body).to include "data-target='#blizzard-graph-modal'"
        expect(response.body).to include "id='blizzard-graph-modal'"
        expect(response.body).to include "id='blizzard-stats-chart'"
      end
    end

    context 'chart labels are in Wellington time, not UTC' do
      let!(:snapshot) { BlizzardStatSnapshot.create!(captured_at: Time.utc(2026, 7, 9, 2, 48), posts: 1, entries: 1, notes: 1) }
      before { get comfy_admin_substack_blizzard_path(days: 14), headers: http_auth_headers }

      it { expect(response.body).to include '9 Jul 14:48' }  # 02:48 UTC + 12
      it { expect(response.body).to_not include '9 Jul 02:48' }
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

  describe 'weighted repost API (local task)' do
    let(:new_url) { 'https://substack.com/profile/4619740-mikey-clarke/note/c-333' }

    describe 'POST repost/tick.json' do
      before { post comfy_admin_substack_blizzard_repost_tick_path(format: :json), headers: http_auth_headers }

      it { expect(response).to have_http_status :success }
      it { expect(response.parsed_body['uid']).to eq 'u0' }
      it { expect(response.parsed_body['body_json']).to eq({ 'type' => 'doc' }) }
      it { expect(response.parsed_body['post_url']).to eq categorization.url }
      it 'claims by stamping last_reposted_at' do
        expect(BlizzardScheduleConfig.instance.last_reposted_at).to be_present
      end
    end

    describe 'GET repost/preview.json (dry run, no claiming)' do
      before { get comfy_admin_substack_blizzard_repost_preview_path(format: :json), headers: http_auth_headers }

      it { expect(response.parsed_body['uid']).to eq 'u0' }
      it { expect(BlizzardScheduleConfig.instance.last_reposted_at).to be_nil }
    end

    describe 'POST repost/confirm.json' do
      before do
        post comfy_admin_substack_blizzard_repost_confirm_path(format: :json),
             params: { categorization_id: categorization.id, uid: 'u0', url: new_url, timestamp: '2026-07-04T00:00:00Z' },
             headers: http_auth_headers
      end

      it { expect(response.parsed_body['ok']).to be true }
      it { expect(categorization.reload.data['blizzard'][0]['notes'].map { |n| n['url'] }).to include new_url }

      it 'is idempotent — a repeat confirm does not double-append' do
        post comfy_admin_substack_blizzard_repost_confirm_path(format: :json),
             params: { categorization_id: categorization.id, uid: 'u0', url: new_url, timestamp: '2026-07-04T00:00:00Z' },
             headers: http_auth_headers
        expect(categorization.reload.data['blizzard'][0]['notes'].count { |n| n['url'] == new_url }).to eq 1
      end
    end
  end

  describe 'GET quotation/preview.json (local preview task)' do
    let!(:quotation) do
      SubstackQuotation.create!(quotation: 'a memorable blurb', comment_url: 'https://x/comment/1',
                                post_title: 'Ch 1', post_url: 'https://mikeyclarke.substack.com/p/ch-1',
                                author_name: 'Eva', author_url: 'https://substack.com/@eva')
    end

    describe 'a random quotation' do
      before { get comfy_admin_substack_blizzard_quotation_preview_path(format: :json), headers: http_auth_headers }

      it { expect(response).to have_http_status :success }
      it { expect(response.parsed_body['text']).to eq 'a memorable blurb' }
      it { expect(response.parsed_body['post_url']).to eq 'https://mikeyclarke.substack.com/p/ch-1' }
      it { expect(response.parsed_body['body_json']['type']).to eq 'doc' }
    end

    describe 'a specific quotation by id' do
      let!(:other) { SubstackQuotation.create!(quotation: 'a different blurb', comment_url: 'https://x/comment/2') }
      before { get comfy_admin_substack_blizzard_quotation_preview_path(id: other.id, format: :json), headers: http_auth_headers }

      it { expect(response.parsed_body['text']).to eq 'a different blurb' }
    end

    describe 'no quotations exist' do
      before do
        SubstackQuotation.delete_all
        get comfy_admin_substack_blizzard_quotation_preview_path(format: :json), headers: http_auth_headers
      end

      it { expect(response.parsed_body).to eq({}) }
    end
  end

  describe 'POST settings' do
    before do
      post comfy_admin_substack_blizzard_settings_path,
           params: { cooldown_hours: 8 }, headers: http_auth_headers
    end

    it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14) }
    it { expect(BlizzardScheduleConfig.instance.cooldown_hours).to eq 8 }

    context 'invalid cooldown is rejected' do
      before do
        post comfy_admin_substack_blizzard_settings_path,
             params: { cooldown_hours: -1 }, headers: http_auth_headers
      end
      it { expect(flash[:danger]).to be_present }
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

    context 'an unattached entry (no categorization_id)' do
      before do
        BlizzardScheduleConfig.instance.update!(
          data: { 'blizzard' => [{ 'uid' => 'un1', 'text' => 'unattached text', 'body_json' => {}, 'notes' => [] }] }
        )
        post comfy_admin_substack_blizzard_reseed_path,
             params: { categorization_id: '', uid: 'un1',
                       note_url: 'https://substack.com/@mikeyclarke/note/c-999', days: 14 },
             headers: http_auth_headers
      end

      it { expect(flash[:success]).to be_present }
      it { expect(BlizzardScheduleConfig.instance.data['blizzard'][0]['text']).to start_with 'reseeded' }
    end
  end

  describe 'POST reseed, json format (async from the Next repost suggestion widget)' do
    let(:rich_body) { { 'type' => 'doc', 'content' => [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'reseeded' }] }] } }

    before do
      SubstackSyncConfig.instance.update!(session_cookie: 'sess')
      stub_request(:get, 'https://substack.com/api/v1/reader/comment/999')
        .to_return(status: 200, body: { 'comment' => { 'body_json' => rich_body } }.to_json)
      post comfy_admin_substack_blizzard_reseed_path(format: :json),
           params: { categorization_id: categorization.id, uid: 'u0',
                     note_url: 'https://substack.com/@mikeyclarke/note/c-999' },
           headers: http_auth_headers
    end

    it { expect(response).to have_http_status :success }
    it { expect(response.parsed_body['success']).to be true }
    it { expect(response.parsed_body['text']).to start_with 'reseeded' }
    it { expect(response.parsed_body['html']).to include '<p>reseeded</p>' }

    context 'fetch fails' do
      let(:rich_body) { {} }

      it { expect(response).to have_http_status :unprocessable_entity }
      it { expect(response.parsed_body['success']).to be false }
      it { expect(response.parsed_body['error']).to be_present }
    end
  end

  describe 'GET next_repost_suggestion (Regenerate)' do
    it 'renders a fresh fragment with no page chrome' do
      allow(Substack::Blizzard::WeightedPicker).to receive(:execute).and_return(
        { 'categorization_id' => categorization.id, 'uid' => 'u0', 'text' => 'regenerated pick', 'body_json' => { 'type' => 'doc' } }
      )
      get comfy_admin_substack_blizzard_next_repost_suggestion_path, headers: http_auth_headers

      expect(response.body).to include 'regenerated pick'
      expect(response.body).to include 'Regenerate'
      expect(response.body).to_not include '<html'
    end

    it 'shows the nothing-eligible message when there is no pick' do
      allow(Substack::Blizzard::WeightedPicker).to receive(:execute).and_return(nil)
      get comfy_admin_substack_blizzard_next_repost_suggestion_path, headers: http_auth_headers

      expect(response.body).to include 'Nothing eligible to suggest right now.'
    end
  end

  describe 'POST add_note (manual paste-back)' do
    include ActiveSupport::Testing::TimeHelpers

    context 'with a url' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0',
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', days: 14 },
             headers: http_auth_headers
      end

      it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14) }
      it { expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 2 }
      it 'resets the suggestion pacing clock' do
        expect(BlizzardScheduleConfig.instance.last_reposted_at).to be_present
      end
    end

    context 'a missing url does not reset the suggestion pacing clock' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0', url: '', days: 14 },
             headers: http_auth_headers
      end

      it { expect(BlizzardScheduleConfig.instance.last_reposted_at).to be_nil }
    end

    context 'retains the page number on redirect' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0',
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', days: 14, page: 3 },
             headers: http_auth_headers
      end

      it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14, page: 3) }
    end

    context 'resolves the real creation timestamp from Substack when available' do
      before do
        SubstackSyncConfig.instance.update!(session_cookie: 'sess')
        stub_request(:get, 'https://substack.com/api/v1/reader/comment/222')
          .to_return(status: 200, body: { 'comment' => { 'date' => '2025-06-21T07:00:00Z' } }.to_json)
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0',
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', days: 14 },
             headers: http_auth_headers
      end

      it { expect(categorization.reload.data['blizzard'][0]['notes'].last['timestamp']).to eq '2025-06-21T07:00:00Z' }
    end

    context 'falls back to the current time when the Substack lookup fails' do
      around { |example| travel_to(Time.utc(2026, 7, 4, 12, 0, 0)) { example.run } }

      before do
        SubstackSyncConfig.instance.update!(session_cookie: 'sess')
        stub_request(:get, 'https://substack.com/api/v1/reader/comment/222').to_return(status: 500, body: 'boom')
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0',
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-222', days: 14 },
             headers: http_auth_headers
      end

      it { expect(categorization.reload.data['blizzard'][0]['notes'].last['timestamp']).to eq '2026-07-04T12:00:00Z' }
    end

    context 'falls back to the current time when the url has no recognizable comment id' do
      around { |example| travel_to(Time.utc(2026, 7, 4, 12, 0, 0)) { example.run } }

      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0', url: 'https://example.com/not-a-note', days: 14 },
             headers: http_auth_headers
      end

      it { expect(categorization.reload.data['blizzard'][0]['notes'].last['timestamp']).to eq '2026-07-04T12:00:00Z' }
    end

    context 'missing url' do
      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: categorization.id, uid: 'u0', url: '', days: 14 },
             headers: http_auth_headers
      end
      it { expect(categorization.reload.data['blizzard'][0]['notes'].size).to eq 1 }
      it { expect(flash[:danger]).to be_present }
    end

    context 'an unattached entry (no categorization_id)' do
      before do
        BlizzardScheduleConfig.instance.update!(
          data: { 'blizzard' => [{ 'uid' => 'un1', 'text' => 'unattached text', 'notes' => [] }] }
        )
        post comfy_admin_substack_blizzard_add_note_path,
             params: { categorization_id: '', uid: 'un1',
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-333', days: 14 },
             headers: http_auth_headers
      end

      it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14) }
      it { expect(flash[:success]).to be_present }
      it { expect(BlizzardScheduleConfig.instance.data['blizzard'][0]['notes'].size).to eq 1 }
      it { expect(BlizzardScheduleConfig.instance.data['blizzard'][0]['notes'].first['likes']).to eq 0 }
    end

    context 'a quotation (quotation_id, no categorization_id/uid)' do
      let!(:quotation) { SubstackQuotation.create!(quotation: 'zing', comment_url: 'https://x/comment/1') }

      before do
        post comfy_admin_substack_blizzard_add_note_path,
             params: { quotation_id: quotation.id,
                       url: 'https://substack.com/profile/4619740-mikey-clarke/note/c-444' },
             headers: http_auth_headers
      end

      it { expect(flash[:success]).to be_present }
      it { expect(quotation.reload.notes.size).to eq 1 }
      it { expect(quotation.reload.notes.first).to include('url' => 'https://substack.com/profile/4619740-mikey-clarke/note/c-444', 'likes' => 0) }
    end
  end

  describe 'GET job_progress.json' do
    before do
      JobProgress.begin!('backfill_all', label: 'Backfill all posts’ notes', total: 10).update!(completed: 4)
      JobProgress.begin!('refresh_note_post_likes', label: 'Refresh', total: 5).finish!
      get comfy_admin_substack_blizzard_job_progress_path(format: :json), headers: http_auth_headers
    end

    it { expect(response).to have_http_status :success }
    it { expect(response.parsed_body.size).to eq 1 }
    it { expect(response.parsed_body.first['key']).to eq 'backfill_all' }
    it { expect(response.parsed_body.first['completed']).to eq 4 }
    it { expect(response.parsed_body.first['percent']).to eq 40 }
    it { expect(response.parsed_body.first['status']).to eq 'running' }
    it 'omits finished jobs so their bar disappears' do
      expect(response.parsed_body.map { |r| r['key'] }).to_not include('refresh_note_post_likes')
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
      allow(RefreshNotePostLikesJob).to receive(:perform_later)
      post comfy_admin_substack_blizzard_refresh_likes_path, headers: http_auth_headers
    end

    it { expect(RefreshNotePostLikesJob).to have_received(:perform_later) }
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

  describe 'POST backfill_unattached' do
    before do
      allow(BackfillUnattachedNotesJob).to receive(:perform_later)
      post comfy_admin_substack_blizzard_backfill_unattached_path, headers: http_auth_headers
    end

    it { expect(BackfillUnattachedNotesJob).to have_received(:perform_later) }
    it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14) }
    it { expect(flash[:success]).to be_present }
  end

  describe 'POST notes-json (update_notes_json)' do
    context 'valid JSON' do
      before do
        post comfy_admin_substack_blizzard_notes_json_path,
             params: { data_json_text: '{"notes":["https://x/note/c-1"]}' }, headers: http_auth_headers
      end

      it { expect(BlizzardScheduleConfig.instance.data).to eq('notes' => ['https://x/note/c-1']) }
      it { expect(response).to redirect_to comfy_admin_substack_blizzard_path(days: 14) }
      it { expect(flash[:success]).to be_present }
    end

    context 'invalid JSON' do
      before { post comfy_admin_substack_blizzard_notes_json_path, params: { data_json_text: 'not json' }, headers: http_auth_headers }

      it { expect(flash[:danger]).to be_present }
    end
  end
end
