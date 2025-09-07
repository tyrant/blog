require 'rails_helper'

RSpec.describe PaginationComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:page_no) { 1 }
  subject { described_class.new page_no: page_no }

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
    it { expect(subject.instance_variable_get(:@cur_page_no)).to eq(1) }
    it { expect(subject.instance_variable_get(:@already_displayed_1_to_n_ellipsis)).to be false }
    it { expect(subject.instance_variable_get(:@already_displayed_n_to_page_count_ellipsis)).to be false }

    context 'when page_no is nil' do
      let(:page_no) { nil }
      it { expect(subject.instance_variable_get(:@cur_page_no)).to eq(1) }
    end

    context 'when page_no is a string' do
      let(:page_no) { '3' }
      it { expect(subject.instance_variable_get(:@cur_page_no)).to eq(3) }
    end
  end

  describe 'private methods' do
    describe '#n_near_start_cur_end?' do
      let(:page_no) { 5 }

      before { allow(subject).to receive(:pages_total_count).and_return(10) }

      describe 'pages near start' do
        it { expect(subject.send(:n_near_start_cur_end?, n: 1)).to be true }
        it { expect(subject.send(:n_near_start_cur_end?, n: 2)).to be true }
      end

      describe 'pages near current' do
        it { expect(subject.send(:n_near_start_cur_end?, n: 4)).to be true }
        it { expect(subject.send(:n_near_start_cur_end?, n: 5)).to be true }
        it { expect(subject.send(:n_near_start_cur_end?, n: 6)).to be true }
      end

      describe 'pages near end' do
        it { expect(subject.send(:n_near_start_cur_end?, n: 9)).to be true }
        it { expect(subject.send(:n_near_start_cur_end?, n: 10)).to be true }
      end

      describe 'pages not near start, current, or end' do
        it { expect(subject.send(:n_near_start_cur_end?, n: 3)).to be false }
        it { expect(subject.send(:n_near_start_cur_end?, n: 7)).to be false }
        it { expect(subject.send(:n_near_start_cur_end?, n: 8)).to be false }
      end

      context 'with custom distance' do
        it { expect(subject.send(:n_near_start_cur_end?, n: 3, distance: 2)).to be true }
        it { expect(subject.send(:n_near_start_cur_end?, n: 7, distance: 2)).to be true }
      end
    end

    describe '#prev_page_no' do
      context 'when on first page' do
        let(:page_no) { 1 }
        it { expect(subject.send(:prev_page_no)).to eq(1) }
      end

      context 'when on page greater than 1' do
        let(:page_no) { 3 }
        it { expect(subject.send(:prev_page_no)).to eq(2) }
      end
    end

    describe '#next_page_no' do
      before { allow(subject).to receive(:pages_total_count).and_return(5) }

      context 'when on last page' do
        let(:page_no) { 5 }
        it { expect(subject.send(:next_page_no)).to eq(5) }
      end

      context 'when not on last page' do
        let(:page_no) { 3 }
        it { expect(subject.send(:next_page_no)).to eq(4) }
      end
    end

    describe '#page_size' do
      it { expect(subject.send(:page_size)).to eq(10) }
    end

    describe '#cur_page_floor' do
      context 'on page 1' do
        let(:page_no) { 1 }
        it { expect(subject.send(:cur_page_floor)).to eq(1) }
      end

      context 'on page 3' do
        let(:page_no) { 3 }
        it { expect(subject.send(:cur_page_floor)).to eq(21) }
      end
    end
  end

  describe 'rendering' do
    before { allow_any_instance_of(described_class).to receive(:params).and_return({ category: nil }) }
    
    let(:rendered) { render_inline(subject) }

    it { expect(rendered).to be_present }
    it { expect(subject.private_methods).to include(:prev_page_no) }
    it { expect(subject.private_methods).to include(:next_page_no) }
    it { expect(subject.private_methods).to include(:page_size) }
    it { expect(subject.private_methods).to include(:cur_page_floor) }
  end
end
