Rails.application.routes.draw do
  resources :emails, only: :create
  get 'posts/:id/prev_nek', to: 'posts#prev_nek', as: 'prev_nek'
  root to: 'application#index'

  comfy_route :blog_admin, path: 'admin'
  comfy_route :blog, path: "blog"

  # Ensure that this route is defined last
  #comfy_route :cms_admin, path: 'admin'
  comfy_route_cms_admin
  comfy_route :cms, path: "/"

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
