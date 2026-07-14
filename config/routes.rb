Rails.application.routes.draw do
  get 'blog', to: 'posts#index'
  get 'posts/:id/prev_nek', to: 'posts#prev_nek', as: 'prev_nek'
  get 'privacy', to: 'application#privacy'
  get 'contact', to: 'application#contact'
  resources :landing, only: [:index] do
    collection do
      post :submit
      get :download
    end
  end
  root to: 'application#index'

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Job queue dashboard — before Comfy's /admin catch-all so it isn't intercepted.
  # Auth is enforced by MissionControlBaseController (Comfy admin credentials).
  mount MissionControl::Jobs::Engine, at: "/admin/jobs"

  # Copypasta'd from the Mailkick gem. Mailkick already inserts these routes at
  # the end of this file's routes ... but turns out if they're *after* Comfy's
  # routes, Comfy intercepts Mailkick's routes and b0rks.
  # 
  # But place these routes *before* Comfy's routes, like so, and all is well.
  #
  unless respond_to?(:has_named_route?) && has_named_route?("mailkick")
    mount Mailkick::Engine => "/mailkick" if Mailkick.mount
  end
  Mailkick::Engine.routes.draw do
    resources :subscriptions, only: [:show] do
      match :unsubscribe, on: :member, via: [:get, :post]
      get :subscribe, on: :member
    end
  end

  get 'the-sex-commandos-thwart-the-third-vaginal-apocalypse',
    to: 'application#apocalypse',
    as: 'apocalypse'
  get 'the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-one-the-knights-of-raw-phwoar',
    to: 'application#phwoar',
    as: 'phwoar'
  get 'the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-two-the-soviet-sluts-superb',
    to: 'application#superb',
    as: 'superb'
  get 'the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-three-the-cervical-supremacy',
    to: 'application#supremacy',
    as: 'supremacy'
  get 'the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-four-the-praetorian-prostitutes',
    to: 'application#praetorian',
    as: 'praetorian'

  get 'apocalypse',
    to: redirect('the-sex-commandos-thwart-the-third-vaginal-apocalypse')
  get 'apocalypse/1-raw-phwoar',
    to: redirect('the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-one-the-knights-of-raw-phwoar')
  get 'apocalypse/2-soviet-sluts-superb',
    to: redirect('the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-two-the-soviet-sluts-superb')
  get 'apocalypse/3-cervical-supremacy',
    to: redirect('the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-three-the-cervical-supremacy')
  get 'apocalypse/4-praetorian-prostitutes',
    to: redirect('the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-four-the-praetorian-prostitutes')

  get 'blog/:year/:month/:slug', to: 'posts#show', constraints: { year: /\d{4}/, month: /\d{1,2}/ }

  scope module: :comfy, as: :comfy do
    scope module: :admin do
      resource :substack_sync_config,
               as: :admin_substack_sync_config,
               path: "admin/substack-sync",
               only: %i[edit update] do
        post :recapture
      end

      get  "admin/reply-drafter",          to: "reply_drafter#show",     as: :admin_reply_drafter
      post "admin/reply-drafter/generate", to: "reply_drafter#generate", as: :admin_reply_drafter_generate

      get    "admin/reply-tracker",     to: "reply_tracker#index",   as: :admin_reply_tracker
      post   "admin/reply-tracker/log", to: "reply_tracker#create",  as: :admin_reply_tracker_log
      delete "admin/reply-tracker/:id", to: "reply_tracker#destroy", as: :admin_reply_tracker_delete

      get    "admin/quotations",          to: "quotations#index",   as: :admin_quotations
      post   "admin/quotations",          to: "quotations#create"
      get    "admin/quotations/:id/edit", to: "quotations#edit",    as: :edit_admin_quotation
      patch  "admin/quotations/:id",      to: "quotations#update"
      delete "admin/quotations/:id",      to: "quotations#destroy", as: :admin_quotation

      resources :tags, as: :admin_tags, path: "admin/tags", except: %i[show]

      get  "admin/substack-blizzard",             to: "substack_blizzard#index",       as: :admin_substack_blizzard
      post "admin/substack-blizzard/repost/tick",    to: "substack_blizzard#repost_tick",    as: :admin_substack_blizzard_repost_tick
      get  "admin/substack-blizzard/repost/preview", to: "substack_blizzard#repost_preview", as: :admin_substack_blizzard_repost_preview
      post "admin/substack-blizzard/repost/confirm", to: "substack_blizzard#repost_confirm", as: :admin_substack_blizzard_repost_confirm
      post "admin/substack-blizzard/settings",       to: "substack_blizzard#update_settings", as: :admin_substack_blizzard_settings
      post "admin/substack-blizzard/backfill-all",  to: "substack_blizzard#backfill_all",  as: :admin_substack_blizzard_backfill_all
      post "admin/substack-blizzard/refresh-likes",  to: "substack_blizzard#refresh_likes",  as: :admin_substack_blizzard_refresh_likes
      get  "admin/substack-blizzard/job-progress",   to: "substack_blizzard#job_progress",   as: :admin_substack_blizzard_job_progress
      post "admin/substack-blizzard/backfill-post", to: "substack_blizzard#backfill_post", as: :admin_substack_blizzard_backfill_post
      post "admin/substack-blizzard/create-note", to: "substack_blizzard#create_note", as: :admin_substack_blizzard_create_note
      post "admin/substack-blizzard/add-note",    to: "substack_blizzard#add_note",    as: :admin_substack_blizzard_add_note
      post "admin/substack-blizzard/reseed",      to: "substack_blizzard#reseed",      as: :admin_substack_blizzard_reseed
    end
  end

  comfy_route :blog_admin, path: 'admin'
  comfy_route :blog, path: "blog"

  # Ensure that this route is defined last
  #comfy_route :cms_admin, path: 'admin'
  comfy_route_cms_admin

  # Comfy CMS catch-all route with constraint to exclude /rails/* paths
  # ActiveStorage routes are automatically loaded by Rails as an engine
  # This constraint prevents CMS from intercepting them
  class ComfyCmsConstraint
    def matches?(request)
      # Allow CMS to handle everything EXCEPT /rails/* paths
      !request.path.start_with?('/rails/')
    end
  end

  # Manually define CMS routes instead of using comfy_route to apply constraint
  constraints(ComfyCmsConstraint.new) do
    get '(*cms_path)', to: 'comfy/cms/content#show', as: :comfy_cms_render_page
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
