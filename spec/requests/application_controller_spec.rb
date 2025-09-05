require 'rails_helper'

RSpec.describe 'ApplicationController', type: :request do
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }

  describe 'GET /' do
    it 'redirects to apocalypse path' do
      get '/'
      expect(response).to redirect_to('/the-sex-commandos-thwart-the-third-vaginal-apocalypse')
    end
  end

  describe 'GET /the-sex-commandos-thwart-the-third-vaginal-apocalypse' do
    it 'renders successfully' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse'
      expect(response).to have_http_status(:success)
    end

    it 'sets random cover image' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse'
      expect(response.body).to include('web-bg-only')
    end
  end

  describe 'GET /the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-one-the-knights-of-raw-phwoar' do
    it 'renders successfully' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-one-the-knights-of-raw-phwoar'
      expect(response).to have_http_status(:success)
    end

    it 'displays Amazon link' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-one-the-knights-of-raw-phwoar'
      expect(response.body).to include('B0CKBRWKC3')
    end
  end

  describe 'GET /the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-two-the-soviet-sluts-superb' do
    it 'renders successfully' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-two-the-soviet-sluts-superb'
      expect(response).to have_http_status(:success)
    end

    it 'displays Amazon link' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-two-the-soviet-sluts-superb'
      expect(response.body).to include('B0CNXPRP6R')
    end
  end

  describe 'GET /the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-three-the-cervical-supremacy' do
    it 'renders successfully' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-three-the-cervical-supremacy'
      expect(response).to have_http_status(:success)
    end

    it 'displays Amazon link' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-three-the-cervical-supremacy'
      expect(response.body).to include('B0CTHHZM15')
    end
  end

  describe 'GET /the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-four-the-praetorian-prostitutes' do
    it 'renders successfully' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-four-the-praetorian-prostitutes'
      expect(response).to have_http_status(:success)
    end

    it 'displays Amazon link' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-four-the-praetorian-prostitutes'
      expect(response.body).to include('B0D88MR374')
    end
  end

  describe 'GET /contact' do
    it 'renders successfully' do
      get '/contact'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'NSFW cookie handling' do
    it 'handles boolean cookie conversion' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse', headers: { 'Cookie' => 'banish_nsfw_completely=true' }
      expect(response).to have_http_status(:success)
    end

    it 'sets default NSFW options when no cookies present' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'navigation setup' do
    let!(:category1) { create :category, label: 'Shite Advice', site: site }
    let!(:category2) { create :category, label: 'Whimsy', site: site }

    it 'includes blog categories in navigation' do
      get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse'
      expect(response.body).to include('Shite Advice')
      expect(response.body).to include('Whimsy')
    end
  end
end
