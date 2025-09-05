require 'rails_helper'

RSpec.describe ModalComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:type) { 'test' }
  let(:component) { described_class.new(type: type) }

  describe '#initialize' do
    it 'sets the type attribute' do
      expect(component.instance_variable_get(:@type)).to eq(type)
    end
  end

  describe 'rendering' do
    subject { render_inline(component) { 'Modal content goes here' } }

    it 'renders the component successfully' do
      expect(subject).to be_present
    end

    it 'includes the modal controller data attribute' do
      expect(subject.css('[data-controller="modal"]')).to be_present
    end

    it 'generates correct modal ID based on type' do
      modal = subject.css("#modal_#{type}").first
      expect(modal).to be_present
    end

    it 'includes proper ARIA attributes for accessibility' do
      modal = subject.css("#modal_#{type}").first
      expect(modal['aria-labelledby']).to eq('modal-title')
      expect(modal['aria-modal']).to eq('true')
      expect(modal['role']).to eq('dialog')
    end

    it 'includes Alpine.js data attributes' do
      modal = subject.css("#modal_#{type}").first
      expect(modal['x-data']).to include('isOpen: false')
      expect(modal['x-on:open-modal']).to eq('isOpen=true')
    end

    it 'renders the backdrop overlay with correct classes' do
      backdrop = subject.css('.fixed.inset-0.bg-gray-500.bg-opacity-75').first
      expect(backdrop).to be_present
      expect(backdrop['x-show']).to eq('isOpen')
    end

    it 'includes backdrop transition attributes' do
      backdrop = subject.css('.bg-gray-500.bg-opacity-75').first
      expect(backdrop['x-transition:enter']).to eq('ease-out duration-300')
      expect(backdrop['x-transition:enter-start']).to eq('opacity-0')
      expect(backdrop['x-transition:enter-end']).to eq('opacity-100')
      expect(backdrop['x-transition:leave']).to eq('ease-in duration-200')
      expect(backdrop['x-transition:leave-start']).to eq('opacity-100')
      expect(backdrop['x-transition:leave-end']).to eq('opacity-0')
    end

    it 'renders the modal container with correct classes' do
      container = subject.css('.fixed.z-10.inset-0.overflow-y-auto').first
      expect(container).to be_present
      expect(container['x-show']).to eq('isOpen')
    end

    it 'includes modal container transition attributes' do
      container = subject.css('.fixed.z-10.inset-0.overflow-y-auto').first
      expect(container['x-transition:enter']).to eq('ease-out duration-300')
      expect(container['x-transition:enter-start']).to eq('opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95')
      expect(container['x-transition:enter-end']).to eq('opacity-100 translate-y-0 sm:scale-100')
      expect(container['x-transition:leave']).to eq('ease-in duration-200')
      expect(container['x-transition:leave-start']).to eq('opacity-100 translate-y-0 sm:scale-100')
      expect(container['x-transition:leave-end']).to eq('opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95')
    end

    it 'renders the modal content area with correct styling' do
      content_area = subject.css('.relative.bg-white.rounded-lg').first
      expect(content_area).to be_present
      expect(content_area['class']).to include('shadow-xl')
      expect(content_area['class']).to include('transform')
      expect(content_area['class']).to include('transition')
    end

    it 'renders the provided content' do
      expect(subject.text).to include('Modal content goes here')
    end

    context 'when type is not "irritate"' do
      let(:type) { 'normal' }

      it 'includes click outside to close functionality' do
        content_area = subject.css('.relative.bg-white.rounded-lg').first
        expect(content_area['x-on:click.outside']).to eq('isOpen=false')
      end
    end

    context 'when type is "irritate"' do
      let(:type) { 'irritate' }

      it 'does not include click outside to close functionality' do
        content_area = subject.css('.relative.bg-white.rounded-lg').first
        expect(content_area['x-on:click.outside']).to be_nil
      end

      it 'generates correct modal ID' do
        modal = subject.css('#modal_irritate').first
        expect(modal).to be_present
      end
    end

    context 'with different type values' do
      let(:type) { 'confirmation' }

      it 'generates correct modal ID' do
        modal = subject.css('#modal_confirmation').first
        expect(modal).to be_present
      end

      it 'includes click outside to close functionality' do
        content_area = subject.css('.relative.bg-white.rounded-lg').first
        expect(content_area['x-on:click.outside']).to eq('isOpen=false')
      end
    end

    context 'with complex content' do
      subject do
        render_inline(component) do
          '<h2>Modal Title</h2><p>This is modal content with <strong>HTML</strong>.</p>'.html_safe
        end
      end

      it 'renders complex HTML content' do
        expect(subject.text).to include('Modal Title')
        expect(subject.text).to include('This is modal content with HTML.')
        expect(subject.css('h2')).to be_present
        expect(subject.css('strong')).to be_present
      end
    end

    context 'with no content' do
      subject { render_inline(component) }

      it 'renders empty modal content area' do
        content_area = subject.css('.relative.bg-white.rounded-lg').first
        expect(content_area).to be_present
        expect(content_area.text.strip).to be_empty
      end
    end
  end
end
