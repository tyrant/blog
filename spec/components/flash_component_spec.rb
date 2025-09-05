require 'rails_helper'

RSpec.describe FlashComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:message) { 'This is a flash message' }
  let(:component) { described_class.new(message: message) }

  describe '#initialize' do
    it 'sets the message attribute' do
      expect(component.instance_variable_get(:@message)).to eq(message)
    end
  end

  describe 'rendering' do
    context 'when message is present' do
      subject { render_inline(component) }

      it 'renders the component successfully' do
        expect(subject).to be_present
      end

      it 'includes the flash controller data attribute' do
        expect(subject.css('[data-controller="flash"]')).to be_present
      end

      it 'includes the flash target data attribute' do
        expect(subject.css('[data-flash-target="banner"]')).to be_present
      end

      it 'displays the message text' do
        expect(subject.text).to include(message)
      end

      it 'applies correct CSS classes for styling' do
        # Main container
        expect(subject.css('.bg-indigo-600')).to be_present
        
        # Content wrapper
        expect(subject.css('.max-w-7xl.mx-auto')).to be_present
        expect(subject.css('.py-3.px-3')).to be_present
        
        # Flex layout
        expect(subject.css('.flex.items-center.justify-between')).to be_present
        
        # Icon styling
        expect(subject.css('.bg-indigo-800')).to be_present
        expect(subject.css('.text-white')).to be_present
        
        # Message text styling
        expect(subject.css('.font-medium.text-white.text-center')).to be_present
        
        # Close button styling
        expect(subject.css('.hover\\:bg-indigo-500')).to be_present
      end

      it 'includes the warning icon SVG' do
        svg = subject.css('svg').first
        expect(svg).to be_present
        expect(svg['class']).to include('h-6 w-6 text-white')
        expect(svg.css('path')).to be_present
      end

      it 'includes the close button with correct action' do
        button = subject.css('button[data-action="click->flash#close"]').first
        expect(button).to be_present
        expect(button['type']).to eq('button')
      end

      it 'includes the close icon SVG' do
        close_svg = subject.css('button svg').first
        expect(close_svg).to be_present
        expect(close_svg['class']).to include('h-6 w-6 text-white')
      end

      it 'includes screen reader text for accessibility' do
        expect(subject.css('.sr-only')).to be_present
        expect(subject.text).to include('Dismiss')
      end

      context 'with HTML in message' do
        let(:message) { '<strong>Important:</strong> This is a test message' }

        it 'properly escapes HTML content' do
          expect(subject.text).to include('<strong>Important:</strong> This is a test message')
        end
      end

      context 'with long message' do
        let(:message) { 'This is a very long flash message that might wrap to multiple lines when displayed in the banner' }

        it 'displays the full message' do
          expect(subject.text).to include(message)
        end
      end

      context 'with special characters' do
        let(:message) { 'Message with "quotes" & ampersands' }

        it 'properly handles special characters' do
          expect(subject.text).to include('Message with "quotes" & ampersands')
        end
      end
    end

    context 'when message is nil' do
      let(:message) { nil }
      subject { render_inline(component) }

      it 'does not render anything' do
        expect(subject.to_html.strip).to be_empty
      end
    end

    context 'when message is empty string' do
      let(:message) { '' }
      subject { render_inline(component) }

      it 'renders the flash banner with empty message' do
        expect(subject.css('[data-controller="flash"]')).to be_present
        # The message area should be empty but the component still renders
        message_element = subject.css('.font-medium.text-white.text-center').first
        expect(message_element.text.strip).to be_empty
      end
    end

    context 'when message is blank' do
      let(:message) { '   ' }
      subject { render_inline(component) }

      it 'renders the component with blank message' do
        expect(subject.css('[data-controller="flash"]')).to be_present
        # The message area contains only whitespace, but "Dismiss" text is still present
        message_element = subject.css('.font-medium.text-white.text-center').first
        expect(message_element.text.strip).to be_empty
      end
    end
  end
end
