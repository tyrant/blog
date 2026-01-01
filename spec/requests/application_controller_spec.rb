# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApplicationController', type: :request do
  let!(:site) { create :site }
  let!(:layout) { create :layout, site: site }

  describe 'GET /' do
    before { get '/' }

    it { expect(response).to redirect_to '/the-sex-commandos-thwart-the-third-vaginal-apocalypse' }
  end

  describe 'GET /the-sex-commandos-thwart-the-third-vaginal-apocalypse' do
    before { get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse' }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'web-bg-only' }
  end

  describe 'GET /the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-one-the-knights-of-raw-phwoar' do
    before { get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-one-the-knights-of-raw-phwoar' }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'B0CKBRWKC3' }
  end

  describe 'GET /the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-two-the-soviet-sluts-superb' do
    before { get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-two-the-soviet-sluts-superb' }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'B0CNXPRP6R' }
  end

  describe 'GET /the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-three-the-cervical-supremacy' do
    before { get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-three-the-cervical-supremacy' }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'B0CTHHZM15' }
  end

  describe 'GET /the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-four-the-praetorian-prostitutes' do
    before { get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse/part-four-the-praetorian-prostitutes' }

    it { expect(response).to have_http_status :success }
    it { expect(response.body).to include 'B0D88MR374' }
  end

  describe 'GET /contact' do
    before { get '/contact' }

    it { expect(response).to have_http_status :success }
  end

  describe 'NSFW cookie handling' do
    context 'with banish_nsfw_completely cookie' do
      before { get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse', headers: { 'Cookie' => 'banish_nsfw_completely=true' } }

      it { expect(response).to have_http_status :success }
    end

    context 'without cookies' do
      before { get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse' }

      it { expect(response).to have_http_status :success }
    end
  end

  describe 'navigation setup' do
    let!(:category1) { create :category, label: 'Shite Advice', site: site }
    let!(:category2) { create :category, label: 'Whimsy', site: site }

    before { get '/the-sex-commandos-thwart-the-third-vaginal-apocalypse' }

    it { expect(response.body).to include 'Shite Advice' }
    it { expect(response.body).to include 'Whimsy' }
  end
end
