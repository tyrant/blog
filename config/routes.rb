Rails.application.routes.draw do
  get 'blog', to: 'posts#index'
  get 'posts/:id/prev_nek', to: 'posts#prev_nek', as: 'prev_nek'
  root to: 'application#index'


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

  comfy_route :blog_admin, path: 'admin'
  comfy_route :blog, path: "blog"

  # Ensure that this route is defined last
  #comfy_route :cms_admin, path: 'admin'
  comfy_route_cms_admin
  comfy_route :cms, path: "/"

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
