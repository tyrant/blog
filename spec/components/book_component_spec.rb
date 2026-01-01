# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:image_path) { '/images/book_cover.jpg' }
  let(:link_path) { '/books/1' }
  let(:number) { 3 }
  let(:title) { 'The Amazing Adventure' }
  let(:blurb) { 'An incredible journey awaits you in this thrilling tale.' }

  subject { described_class.new image_path: image_path, link_path: link_path, number: number, title: title, blurb: blurb }

  describe '#initialize' do
    it { expect(subject.instance_variable_get(:@image_path)).to eq(image_path) }
    it { expect(subject.instance_variable_get(:@link_path)).to eq(link_path) }
    it { expect(subject.instance_variable_get(:@number)).to eq(number) }
    it { expect(subject.instance_variable_get(:@title)).to eq(title) }
    it { expect(subject.instance_variable_get(:@blurb)).to eq(blurb) }
  end

  describe 'rendering' do
    let(:rendered) { render_inline(subject) }
    let(:link) { rendered.css('a').first }
    let(:img) { rendered.css('img').first }

    it { expect(rendered).to be_present }
    it { expect(rendered.css('[data-controller="book"]')).to be_present }
    it { expect(link['href']).to eq(link_path) }
    it { expect(img['src']).to include(image_path) }
    it { expect(img['class']).to include('shadow-xl w-full duration-100 ease-in hover:scale-[1.015]') }
    it { expect(rendered.text).to include('The Sex Commandos Thwart The Third Vaginal Apocalypse') }
    it { expect(rendered.text).to include("~~ Part\u00A0\u00A0#{number}/6 ~~") }
    it { expect(rendered.text).to include(title) }
    it { expect(rendered.text).to include(blurb) }

    describe 'CSS classes' do
      it { expect(rendered.css('[class*="p-[5%]"]')).to be_present }
      it { expect(rendered.css('.h-full')).to be_present }
      it { expect(rendered.css('.bg-white')).to be_present }
      it { expect(rendered.css('.rounded-lg')).to be_present }
      it { expect(rendered.css('.shadow-lg')).to be_present }
      it { expect(rendered.css('.text-center')).to be_present }
      it { expect(rendered.css('.uppercase')).to be_present }
      it { expect(rendered.css('.text-xs')).to be_present }
      it { expect(rendered.css('.text-gray-400')).to be_present }
      it { expect(rendered.to_html).to include("font-['Great_Vibes']") }
      it { expect(rendered.css('.text-lg')).to be_present }
      it { expect(rendered.to_html).to include("font-['Racing_Sans_One']") }
    end

    context 'with different number values' do
      let(:number) { 1 }
      it { expect(rendered.text).to include("~~ Part\u00A0\u00A01/6 ~~") }
    end

    context 'with long title' do
      let(:title) { 'A Very Long Book Title That Might Wrap Multiple Lines' }
      it { expect(rendered.text).to include(title) }
    end

    context 'with long blurb' do
      let(:blurb) { 'This is a very long blurb that describes the book in great detail and might span multiple lines when rendered.' }
      it { expect(rendered.text).to include(blurb) }
    end

    context 'with special characters in content' do
      let(:title) { 'Book & Adventure: "The Quest"' }
      let(:blurb) { 'A tale of <courage> & "determination"' }
      it { expect(rendered.text).to include('Book & Adventure: "The Quest"') }
      it { expect(rendered.text).to include('A tale of <courage> & "determination"') }
    end
  end
end
