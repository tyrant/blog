# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comfy::Admin::SubstackFavouritesController', type: :request do
  let!(:site) { create :site }
  let(:client) { instance_double(Substack::Client) }

  before do
    reset_cms_config
    allow(Substack::Client).to receive(:new).and_return(client)
  end

  describe 'GET index' do
    let!(:eva) { create :substack_user, user_id: 11, handle: 'eva', name: 'Eva Solen', favourite: true }
    let!(:note) do
      SubstackFavouriteItem.create!(substack_user: eva, entity_key: 'c-1', kind: 'note', url: 'https://substack.com/@eva/note/c-1',
                                    excerpt: 'a lovely note', published_at: 1.hour.ago, liked: true)
    end
    let!(:post_item) do
      SubstackFavouriteItem.create!(substack_user: eva, entity_key: 'p-2', kind: 'post', url: 'https://eva.substack.com/p/x',
                                    title: 'A splendid post', excerpt: 'its subtitle', published_at: 2.hours.ago)
    end

    before do
      SubstackFavouriteItem.create!(substack_user: eva, entity_key: 'c-3', kind: 'note', url: 'u', excerpt: 'already done',
                                    published_at: 1.hour.ago, dismissed_at: Time.current)
      SubstackReply.create!(target_url: 'https://eva.substack.com/p/x/comment/9', comment_url: 'https://eva.substack.com/p/x/comment/10', replied_at: 1.hour.ago)
      SubstackEngagement.record!((1..3).map { |i| { user_id: 22, handle: nil, name: 'Keen Kim', content_key: "p-#{i}", kind: 'comment', occurred_at: 1.day.ago } })
      SubstackEngagement.record!([{ user_id: 11, handle: 'eva', name: 'Eva', content_key: 'p-1', kind: 'like', occurred_at: 1.day.ago }])
      get comfy_admin_substack_favourites_path, headers: admin_headers
    end

    it { expect(response).to have_http_status :success }

    it 'lists pending feed items, linking out to Substack' do
      expect(response.body).to include('a lovely note', 'https://substack.com/@eva/note/c-1', 'A splendid post', 'its subtitle')
      expect(response.body).not_to include 'already done'
    end

    it 'flags items already replied to or liked' do
      expect(response.body).to include('replied', '❤')
    end

    it 'has a Done button per item' do
      expect(response.body).to include comfy_dismiss_admin_substack_favourite_item_path(note)
    end

    it 'lists favourites, linking to their Substack user page, with their engagement' do
      expect(response.body).to include('Eva Solen', edit_comfy_admin_substack_user_path(eva), 'https://substack.com/@eva', '1 piece over 1 month')
      expect(response.body).to include comfy_remove_admin_substack_favourite_path(eva)
    end

    it 'suggests engaged accounts that aren’t favourites yet' do
      expect(response.body).to include('Keen Kim', 'https://substack.com/profile/22', 'name="user_id" value="22"')
    end

    it { expect(response.body).to include 'Add Favourite' }
  end

  describe 'GET index filtered by kind' do
    let!(:eva) { create :substack_user, handle: 'eva', favourite: true }

    before do
      SubstackFavouriteItem.create!(substack_user: eva, entity_key: 'c-1', kind: 'note', url: 'u1', excerpt: 'a lovely note', published_at: 1.hour.ago)
      SubstackFavouriteItem.create!(substack_user: eva, entity_key: 'p-2', kind: 'post', url: 'u2', title: 'A splendid post', published_at: 2.hours.ago)
    end

    it 'shows only posts' do
      get comfy_admin_substack_favourites_path(kind: 'post'), headers: admin_headers
      expect(response.body).to include 'A splendid post'
      expect(response.body).not_to include 'a lovely note'
      expect(response.body).to include '<option selected="selected" value="post">Posts</option>'
    end

    it 'shows only Notes' do
      get comfy_admin_substack_favourites_path(kind: 'note'), headers: admin_headers
      expect(response.body).to include 'a lovely note'
      expect(response.body).not_to include 'A splendid post'
    end

    it 'shows both for anything else' do
      get comfy_admin_substack_favourites_path(kind: 'video'), headers: admin_headers
      expect(response.body).to include('a lovely note', 'A splendid post')
    end

    it 'says when a filter leaves nothing' do
      SubstackFavouriteItem.where(kind: 'post').delete_all
      get comfy_admin_substack_favourites_path(kind: 'post'), headers: admin_headers
      expect(response.body).to include 'No posts to reply to.'
    end

    it 'keeps the filter when re-sorting suggestions' do
      SubstackEngagement.record!((1..3).map { |i| { user_id: 22, handle: nil, name: 'Kim', content_key: "p-#{i}", kind: 'like', occurred_at: 1.day.ago } })
      get comfy_admin_substack_favourites_path(kind: 'note', order: 'likes'), headers: admin_headers
      expect(response.body).to include('<input type="hidden" name="kind" id="kind" value="note"', '<input type="hidden" name="order" id="order" value="likes"')
    end
  end

  describe 'GET index while jobs run' do
    before do
      JobProgress.begin!(RefreshSubstackFavouritesJob::PROGRESS_KEY, label: 'r', total: 4)
      JobProgress.begin!(ScanSubstackEngagementJob::PROGRESS_KEY, label: 's', total: 10)
      get comfy_admin_substack_favourites_path, headers: admin_headers
    end

    it { expect(response.body).to include('Refreshing: 0 of 4 favourites', 'Scanning: 0 of 10 posts and Notes') }
  end

  describe 'GET index after jobs finished' do
    before do
      JobProgress.begin!(RefreshSubstackFavouritesJob::PROGRESS_KEY, label: 'r', total: 1).finish!
      JobProgress.begin!(ScanSubstackEngagementJob::PROGRESS_KEY, label: 's', total: 1).finish!
      get comfy_admin_substack_favourites_path, headers: admin_headers
    end

    it { expect(response.body).to include('Feed last refreshed', 'Last scanned') }
  end

  describe 'POST create' do
    def add(params) = post(comfy_create_admin_substack_favourite_path, params: params, headers: admin_headers)

    context 'from the form' do
      before { allow(client).to receive(:public_profile_by_handle).with('eva').and_return('id' => 11, 'handle' => 'eva', 'name' => 'Eva') }

      %w[eva @eva https://substack.com/@eva https://substack.com/@eva/note/c-123 https://substack.com/profile/11-eva].each do |input|
        it "adds “#{input}” with their id and name" do
          add(favourite: input)
          expect(SubstackUser.with_handle('eva').sole).to have_attributes(user_id: 11, name: 'Eva', favourite: true)
          expect(flash[:success]).to include '@eva'
        end
      end

      it 'marks an existing user rather than duplicating them' do
        existing = create :substack_user, user_id: 11, handle: 'eva'
        expect { add(favourite: 'eva') }.not_to change(SubstackUser, :count)
        expect(existing.reload).to be_favourite
      end
    end

    it 'adds by handle alone when the lookup fails' do
      allow(client).to receive(:public_profile_by_handle).and_raise(Substack::Client::Error, 'boom')
      add(favourite: 'eva')
      expect(SubstackUser.with_handle('eva').sole).to have_attributes(user_id: nil, favourite: true)
    end

    it 'refuses an unknown account' do
      allow(client).to receive(:public_profile_by_handle).and_raise(Substack::Client::NotFound, '404')
      add(favourite: 'nobody')
      expect(flash[:danger]).to include 'no Substack account @nobody'
      expect(SubstackUser.count).to eq 0
    end

    it 'refuses gibberish' do
      add(favourite: 'not a handle!')
      expect(flash[:danger]).to include 'enter a Substack handle'
    end

    context 'from a suggestion' do
      it 'adds them, fetching a missing handle' do
        allow(client).to receive(:handle_for).with('22').and_return('kim')
        add(user_id: '22', name: 'Keen Kim')
        expect(SubstackUser.find_by(user_id: 22)).to have_attributes(handle: 'kim', name: 'Keen Kim', favourite: true)
      end

      it 'adds them without a handle when that lookup fails' do
        allow(client).to receive(:handle_for).and_raise(Substack::Client::Error, 'boom')
        add(user_id: '22', name: 'Keen Kim')
        expect(SubstackUser.find_by(user_id: 22)).to have_attributes(handle: nil, favourite: true)
      end
    end

    it 'returns to the page' do
      allow(client).to receive(:public_profile_by_handle).and_return('id' => 11)
      add(favourite: 'eva')
      expect(response).to redirect_to comfy_admin_substack_favourites_path
    end
  end

  describe 'POST remove' do
    let!(:eva) { create :substack_user, favourite: true }

    before { post comfy_remove_admin_substack_favourite_path(eva), headers: admin_headers }

    it { expect(eva.reload).not_to be_favourite }
  end

  describe 'POST refresh' do
    it 'starts a background refresh' do
      expect { post comfy_refresh_admin_substack_favourites_path, headers: admin_headers }.to have_enqueued_job(RefreshSubstackFavouritesJob)
    end

    it 'does not start a second while one runs' do
      JobProgress.begin!(RefreshSubstackFavouritesJob::PROGRESS_KEY, label: 'r', total: 1)
      expect { post comfy_refresh_admin_substack_favourites_path, headers: admin_headers }.not_to have_enqueued_job
      expect(flash[:warning]).to include 'already refreshing'
    end
  end

  describe 'POST scan' do
    it 'starts an incremental scan' do
      expect { post comfy_scan_admin_substack_favourites_path, headers: admin_headers }
        .to have_enqueued_job(ScanSubstackEngagementJob).with(full: false)
    end

    it 'starts a full scan' do
      expect { post comfy_scan_admin_substack_favourites_path(full: 1), headers: admin_headers }
        .to have_enqueued_job(ScanSubstackEngagementJob).with(full: true)
    end

    it 'does not start a second while one runs' do
      JobProgress.begin!(ScanSubstackEngagementJob::PROGRESS_KEY, label: 's', total: 1)
      expect { post comfy_scan_admin_substack_favourites_path, headers: admin_headers }.not_to have_enqueued_job
    end
  end

  describe 'POST dismiss' do
    let(:eva) { create :substack_user, favourite: true }
    let!(:item) { SubstackFavouriteItem.create!(substack_user: eva, entity_key: 'c-1', kind: 'note', url: 'u', published_at: Time.current) }

    it 'removes the row in place over Turbo' do
      post comfy_dismiss_admin_substack_favourite_item_path(item), headers: admin_headers.merge('Accept' => 'text/vnd.turbo-stream.html')
      expect(item.reload.dismissed_at).to be_present
      expect(response.body).to include %(<turbo-stream action="remove" target="substack_favourite_item_#{item.id}">)
    end

    it 'redirects without Turbo' do
      post comfy_dismiss_admin_substack_favourite_item_path(item), headers: admin_headers
      expect(response).to redirect_to comfy_admin_substack_favourites_path
    end

    it 'needs authentication' do
      post comfy_dismiss_admin_substack_favourite_item_path(item)
      expect(response).to have_http_status :unauthorized
      expect(item.reload.dismissed_at).to be_nil
    end
  end
end
