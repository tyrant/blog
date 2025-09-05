require 'rails_helper'

RSpec.describe PaginationComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:page_no) { 1 }
  let(:component) { described_class.new(page_no: page_no) }

  # Mock ComfyBlog configuration and models
  before do
    allow(ComfyBlog).to receive_message_chain(:config, :posts_per_page).and_return(10)
    
    # Mock Comfy::Blog::Post scope chain
    published_scope = double('published_scope')
    category_scope = double('category_scope')
    
    allow(Comfy::Blog::Post).to receive(:published).and_return(published_scope)
    allow(published_scope).to receive(:for_category).and_return(category_scope)
    allow(category_scope).to receive(:count).and_return(25) # Default to 25 posts for testing
  end

  describe '#initialize' do
    it 'sets the current page number' do
      expect(component.instance_variable_get(:@cur_page_no)).to eq(1)
    end

    it 'initializes ellipsis tracking variables' do
      expect(component.instance_variable_get(:@already_displayed_1_to_n_ellipsis)).to be false
      expect(component.instance_variable_get(:@already_displayed_n_to_page_count_ellipsis)).to be false
    end

    context 'when page_no is nil' do
      let(:page_no) { nil }

      it 'defaults to page 1' do
        expect(component.instance_variable_get(:@cur_page_no)).to eq(1)
      end
    end

    context 'when page_no is a string' do
      let(:page_no) { '3' }

      it 'converts to integer' do
        expect(component.instance_variable_get(:@cur_page_no)).to eq(3)
      end
    end
  end

  describe 'private methods' do
    describe '#n_near_start_cur_end?' do
      let(:page_no) { 5 }

      before do
        # Mock 10 total pages
        allow(component).to receive(:pages_total_count).and_return(10)
      end

      it 'returns true for pages near start (within distance of 1)' do
        expect(component.send(:n_near_start_cur_end?, n: 1)).to be true
        expect(component.send(:n_near_start_cur_end?, n: 2)).to be true
      end

      it 'returns true for pages near current (within distance of 1)' do
        expect(component.send(:n_near_start_cur_end?, n: 4)).to be true
        expect(component.send(:n_near_start_cur_end?, n: 5)).to be true
        expect(component.send(:n_near_start_cur_end?, n: 6)).to be true
      end

      it 'returns true for pages near end (within distance of 1)' do
        expect(component.send(:n_near_start_cur_end?, n: 9)).to be true
        expect(component.send(:n_near_start_cur_end?, n: 10)).to be true
      end

      it 'returns false for pages not near start, current, or end' do
        expect(component.send(:n_near_start_cur_end?, n: 3)).to be false
        expect(component.send(:n_near_start_cur_end?, n: 7)).to be false
        expect(component.send(:n_near_start_cur_end?, n: 8)).to be false
      end

      context 'with custom distance' do
        it 'uses the specified distance' do
          expect(component.send(:n_near_start_cur_end?, n: 3, distance: 2)).to be true
          expect(component.send(:n_near_start_cur_end?, n: 7, distance: 2)).to be true
        end
      end
    end

    describe '#prev_page_no' do
      context 'when on first page' do
        let(:page_no) { 1 }

        it 'returns 1' do
          expect(component.send(:prev_page_no)).to eq(1)
        end
      end

      context 'when on page greater than 1' do
        let(:page_no) { 3 }

        it 'returns previous page number' do
          expect(component.send(:prev_page_no)).to eq(2)
        end
      end
    end

    describe '#next_page_no' do
      before do
        allow(component).to receive(:pages_total_count).and_return(5)
      end

      context 'when on last page' do
        let(:page_no) { 5 }

        it 'returns the last page number' do
          expect(component.send(:next_page_no)).to eq(5)
        end
      end

      context 'when not on last page' do
        let(:page_no) { 3 }

        it 'returns next page number' do
          expect(component.send(:next_page_no)).to eq(4)
        end
      end
    end

    describe '#page_size' do
      it 'returns the configured posts per page' do
        expect(component.send(:page_size)).to eq(10)
      end
    end

    describe '#cur_page_floor' do
      context 'on page 1' do
        let(:page_no) { 1 }

        it 'returns 1' do
          expect(component.send(:cur_page_floor)).to eq(1)
        end
      end

      context 'on page 3' do
        let(:page_no) { 3 }

        it 'returns 21' do
          expect(component.send(:cur_page_floor)).to eq(21)
        end
      end
    end
  end

  describe 'rendering' do
    before do
      # Mock params method on the component after rendering context is available
      allow_any_instance_of(described_class).to receive(:params).and_return({ category: nil })
    end

    subject { render_inline(component) }

    it 'renders the component successfully' do
      expect(subject).to be_present
    end

    it 'includes pagination logic methods' do
      # Test that the component has the expected pagination methods
      expect(component.private_methods).to include(:prev_page_no)
      expect(component.private_methods).to include(:next_page_no)
      expect(component.private_methods).to include(:page_size)
      expect(component.private_methods).to include(:cur_page_floor)
    end
  end
end
