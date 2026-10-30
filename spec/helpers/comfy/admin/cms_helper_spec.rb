# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Admin::CmsHelper, type: :helper do
  describe '#comfy_admin_page_title' do
    it 'prefixes the page-header heading' do
      html = '<div class="page-header d-flex"><h2> Substack   Users </h2><a>New</a></div><h2>Other</h2>'
      expect(helper.comfy_admin_page_title(html)).to eq 'Comfy: Substack Users'
    end

    it 'is nil without a page header' do
      expect(helper.comfy_admin_page_title('<h2>Loose</h2>')).to be_nil
    end
  end
end
