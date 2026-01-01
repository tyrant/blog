# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ModalComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:type) { 'test' }
  subject { described_class.new type: type }

  describe '#initialize' do
    it { expect(subject.instance_variable_get(:@type)).to eq(type) }
  end

  describe 'rendering' do
    let(:rendered) { render_inline(subject) { 'Modal content goes here' } }
    let(:modal) { rendered.css("#modal_#{type}").first }
    let(:backdrop) { rendered.css('.fixed.inset-0.bg-gray-500.bg-opacity-75').first }
    let(:container) { rendered.css('.fixed.z-10.inset-0.overflow-y-auto').first }
    let(:content_area) { rendered.css('.relative.bg-white.rounded-lg').first }

    it { expect(rendered).to be_present }
    it { expect(rendered.css('[data-controller="modal"]')).to be_present }
    it { expect(modal).to be_present }

    describe 'ARIA attributes' do
      it { expect(modal['aria-labelledby']).to eq('modal-title') }
      it { expect(modal['aria-modal']).to eq('true') }
      it { expect(modal['role']).to eq('dialog') }
    end

    describe 'Alpine.js attributes' do
      it { expect(modal['x-data']).to include('isOpen: false') }
      it { expect(modal['x-on:open-modal']).to eq('isOpen=true') }
    end

    describe 'backdrop overlay' do
      it { expect(backdrop).to be_present }
      it { expect(backdrop['x-show']).to eq('isOpen') }
      it { expect(backdrop['x-transition:enter']).to eq('ease-out duration-300') }
      it { expect(backdrop['x-transition:enter-start']).to eq('opacity-0') }
      it { expect(backdrop['x-transition:enter-end']).to eq('opacity-100') }
      it { expect(backdrop['x-transition:leave']).to eq('ease-in duration-200') }
      it { expect(backdrop['x-transition:leave-start']).to eq('opacity-100') }
      it { expect(backdrop['x-transition:leave-end']).to eq('opacity-0') }
    end

    describe 'modal container' do
      it { expect(container).to be_present }
      it { expect(container['x-show']).to eq('isOpen') }
      it { expect(container['x-transition:enter']).to eq('ease-out duration-300') }
      it { expect(container['x-transition:enter-start']).to eq('opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95') }
      it { expect(container['x-transition:enter-end']).to eq('opacity-100 translate-y-0 sm:scale-100') }
      it { expect(container['x-transition:leave']).to eq('ease-in duration-200') }
      it { expect(container['x-transition:leave-start']).to eq('opacity-100 translate-y-0 sm:scale-100') }
      it { expect(container['x-transition:leave-end']).to eq('opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95') }
    end

    describe 'content area' do
      it { expect(content_area).to be_present }
      it { expect(content_area['class']).to include('shadow-xl') }
      it { expect(content_area['class']).to include('transform') }
      it { expect(content_area['class']).to include('transition') }
    end

    it { expect(rendered.text).to include('Modal content goes here') }

    context 'when type is not "irritate"' do
      let(:type) { 'normal' }
      it { expect(content_area['x-on:click.outside']).to eq('isOpen=false') }
    end

    context 'when type is "irritate"' do
      let(:type) { 'irritate' }
      it { expect(content_area['x-on:click.outside']).to be_nil }
      it { expect(rendered.css('#modal_irritate').first).to be_present }
    end

    context 'with different type values' do
      let(:type) { 'confirmation' }
      it { expect(rendered.css('#modal_confirmation').first).to be_present }
      it { expect(content_area['x-on:click.outside']).to eq('isOpen=false') }
    end

    context 'with complex content' do
      let(:rendered) do
        render_inline(subject) do
          '<h2>Modal Title</h2><p>This is modal content with <strong>HTML</strong>.</p>'.html_safe
        end
      end
      it { expect(rendered.text).to include('Modal Title') }
      it { expect(rendered.text).to include('This is modal content with HTML.') }
      it { expect(rendered.css('h2')).to be_present }
      it { expect(rendered.css('strong')).to be_present }
    end

    context 'with no content' do
      let(:rendered) { render_inline(subject) }
      let(:content_area) { rendered.css('.relative.bg-white.rounded-lg').first }
      it { expect(content_area).to be_present }
      it { expect(content_area.text.strip).to be_empty }
    end
  end
end
