# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FlashComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:message) { 'This is a flash message' }
  subject { described_class.new message: message }

  describe '#initialize' do
    it { expect(subject.instance_variable_get(:@message)).to eq(message) }
  end

  describe 'rendering' do
    context 'when message is present' do
      let(:rendered) { render_inline(subject) }
      let(:svg) { rendered.css('svg').first }
      let(:button) { rendered.css('button[data-action="click->flash#close"]').first }
      let(:close_svg) { rendered.css('button svg').first }

      it { expect(rendered).to be_present }
      it { expect(rendered.css('[data-controller="flash"]')).to be_present }
      it { expect(rendered.css('[data-flash-target="banner"]')).to be_present }
      it { expect(rendered.text).to include(message) }

      describe 'CSS classes' do
        it { expect(rendered.css('.bg-indigo-600')).to be_present }
        it { expect(rendered.css('.max-w-7xl.mx-auto')).to be_present }
        it { expect(rendered.css('.py-3.px-3')).to be_present }
        it { expect(rendered.css('.flex.items-center.justify-between')).to be_present }
        it { expect(rendered.css('.bg-indigo-800')).to be_present }
        it { expect(rendered.css('.text-white')).to be_present }
        it { expect(rendered.css('.font-medium.text-white.text-center')).to be_present }
        it { expect(rendered.css('.hover\:bg-indigo-500')).to be_present }
      end

      describe 'SVG elements' do
        it { expect(svg).to be_present }
        it { expect(svg['class']).to include('h-6 w-6 text-white') }
        it { expect(svg.css('path')).to be_present }
        it { expect(close_svg).to be_present }
        it { expect(close_svg['class']).to include('h-6 w-6 text-white') }
      end

      describe 'interactive elements' do
        it { expect(button).to be_present }
        it { expect(button['type']).to eq('button') }
      end

      describe 'accessibility' do
        it { expect(rendered.css('.sr-only')).to be_present }
        it { expect(rendered.text).to include('Dismiss') }
      end

      context 'with HTML in message' do
        let(:message) { '<strong>Important:</strong> This is a test message' }
        it { expect(rendered.text).to include('<strong>Important:</strong> This is a test message') }
      end

      context 'with long message' do
        let(:message) { 'This is a very long flash message that might wrap to multiple lines when displayed in the banner' }
        it { expect(rendered.text).to include(message) }
      end

      context 'with special characters' do
        let(:message) { 'Message with "quotes" & ampersands' }
        it { expect(rendered.text).to include('Message with "quotes" & ampersands') }
      end
    end

    context 'when message is nil' do
      let(:message) { nil }
      let(:rendered) { render_inline(subject) }
      it { expect(rendered.to_html.strip).to be_empty }
    end

    context 'when message is empty string' do
      let(:message) { '' }
      let(:rendered) { render_inline(subject) }
      let(:message_element) { rendered.css('.font-medium.text-white.text-center').first }
      it { expect(rendered.css('[data-controller="flash"]')).to be_present }
      it { expect(message_element.text.strip).to be_empty }
    end

    context 'when message is blank' do
      let(:message) { '   ' }
      let(:rendered) { render_inline(subject) }
      let(:message_element) { rendered.css('.font-medium.text-white.text-center').first }
      it { expect(rendered.css('[data-controller="flash"]')).to be_present }
      it { expect(message_element.text.strip).to be_empty }
    end
  end
end
