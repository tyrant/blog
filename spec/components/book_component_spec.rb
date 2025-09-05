require 'rails_helper'

RSpec.describe BookComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:image_path) { '/images/book_cover.jpg' }
  let(:link_path) { '/books/1' }
  let(:number) { 3 }
  let(:title) { 'The Amazing Adventure' }
  let(:blurb) { 'An incredible journey awaits you in this thrilling tale.' }

  let(:component) do
    described_class.new(
      image_path: image_path,
      link_path: link_path,
      number: number,
      title: title,
      blurb: blurb
    )
  end

  describe '#initialize' do
    it 'sets all required attributes' do
      expect(component.instance_variable_get(:@image_path)).to eq(image_path)
      expect(component.instance_variable_get(:@link_path)).to eq(link_path)
      expect(component.instance_variable_get(:@number)).to eq(number)
      expect(component.instance_variable_get(:@title)).to eq(title)
      expect(component.instance_variable_get(:@blurb)).to eq(blurb)
    end
  end

  describe 'rendering' do
    subject { render_inline(component) }

    it 'renders the component successfully' do
      expect(subject).to be_present
    end

    it 'includes the book controller data attribute' do
      expect(subject.css('[data-controller="book"]')).to be_present
    end

    it 'renders the link with correct path' do
      link = subject.css('a').first
      expect(link['href']).to eq(link_path)
    end

    it 'renders the book cover image with correct attributes' do
      img = subject.css('img').first
      expect(img['src']).to include(image_path)
      expect(img['class']).to include('shadow-xl w-full duration-100 ease-in hover:scale-[1.015]')
    end

    it 'displays the series title' do
      expect(subject.text).to include('The Sex Commandos Thwart The Third Vaginal Apocalypse')
    end

    it 'displays the part number correctly formatted' do
      expect(subject.text).to include("~~ Part\u00A0\u00A0#{number}/6 ~~")
    end

    it 'displays the book title' do
      expect(subject.text).to include(title)
    end

    it 'displays the blurb' do
      expect(subject.text).to include(blurb)
    end

    it 'applies correct CSS classes for styling' do
      # Main container
      expect(subject.css('[class*="p-[5%]"]')).to be_present
      expect(subject.css('.h-full')).to be_present
      expect(subject.css('.bg-white')).to be_present
      expect(subject.css('.rounded-lg')).to be_present
      expect(subject.css('.shadow-lg')).to be_present
      expect(subject.css('.text-center')).to be_present

      # Series title styling
      expect(subject.css('.uppercase')).to be_present
      expect(subject.css('.text-xs')).to be_present
      expect(subject.css('.text-gray-400')).to be_present

      # Part number styling - check for font family in class attribute
      expect(subject.to_html).to include("font-['Great_Vibes']")
      expect(subject.css('.text-lg')).to be_present

      # Book title styling - check for font family in class attribute
      expect(subject.to_html).to include("font-['Racing_Sans_One']")

      # Blurb styling
      expect(subject.css('.text-xs')).to be_present
    end

    context 'with different number values' do
      let(:number) { 1 }

      it 'displays the correct part number' do
        expect(subject.text).to include("~~ Part\u00A0\u00A01/6 ~~")
      end
    end

    context 'with long title' do
      let(:title) { 'A Very Long Book Title That Might Wrap Multiple Lines' }

      it 'displays the full title' do
        expect(subject.text).to include(title)
      end
    end

    context 'with long blurb' do
      let(:blurb) { 'This is a very long blurb that describes the book in great detail and might span multiple lines when rendered.' }

      it 'displays the full blurb' do
        expect(subject.text).to include(blurb)
      end
    end

    context 'with special characters in content' do
      let(:title) { 'Book & Adventure: "The Quest"' }
      let(:blurb) { 'A tale of <courage> & "determination"' }

      it 'properly escapes HTML in title' do
        expect(subject.text).to include('Book & Adventure: "The Quest"')
      end

      it 'properly escapes HTML in blurb' do
        expect(subject.text).to include('A tale of <courage> & "determination"')
      end
    end
  end
end
