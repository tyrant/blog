require 'rails_helper'

RSpec.describe ConsentIsSexyYoComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:default_nsfw_options) { { 'banish' => false, 'mouseover' => false, 'always' => false } }
  let(:mode) { 'col' }
  subject { ConsentIsSexyYoComponent.new mode: mode, nsfw_options: default_nsfw_options }

  describe '#initialize' do
    it { is_expected.to be_present }
    
    context 'with default mode' do
      subject { ConsentIsSexyYoComponent.new nsfw_options: default_nsfw_options }
      it { expect(subject.send(:col?)).to be true }
      it { expect(subject.send(:row?)).to be false }
    end

    context 'with row mode' do
      let(:mode) { 'row' }
      it { expect(subject.send(:row?)).to be true }
      it { expect(subject.send(:col?)).to be false }
    end
  end

  describe 'rendering' do
    before { render_inline(subject) }
    
    context 'in col mode' do
      it { expect(rendered_component).to be_present }
    end

    context 'in row mode' do
      let(:mode) { 'row' }
      it { expect(rendered_component).to be_present }
    end
  end

  describe 'banish functionality' do
    it { expect(subject.send(:banish?)).to be false }
    it { expect(subject.send(:banish_disabled?)).to be false }

    context 'when banish is set' do
      let(:default_nsfw_options) { { 'banish' => true, 'mouseover' => false, 'always' => false } }
      it { expect(subject.send(:banish?)).to be true }
    end
  end

  describe 'mouseover functionality' do
    it { expect(subject.send(:mouseover?)).to be false }
    it { expect(subject.send(:mouseover_disabled?)).to be false }

    context 'when mouseover is set' do
      let(:default_nsfw_options) { { 'banish' => false, 'mouseover' => true, 'always' => false } }
      it { expect(subject.send(:mouseover?)).to be true }
    end

    context 'when banish is true' do
      let(:default_nsfw_options) { { 'banish' => true, 'mouseover' => false, 'always' => false } }
      it { expect(subject.send(:mouseover_disabled?)).to be true }
    end
  end

  describe 'always functionality' do
    it { expect(subject.send(:always?)).to be false }
    it { expect(subject.send(:always_disabled?)).to be true }

    context 'when always is set' do
      let(:default_nsfw_options) { { 'banish' => false, 'mouseover' => true, 'always' => true } }
      it { expect(subject.send(:always?)).to be true }
    end

    context 'when banish is true' do
      let(:default_nsfw_options) { { 'banish' => true, 'mouseover' => false, 'always' => false } }
      it { expect(subject.send(:always_disabled?)).to be true }
    end

    context 'when mouseover is false' do
      it { expect(subject.send(:always_disabled?)).to be true }
    end

    context 'when banish is false and mouseover is true' do
      let(:default_nsfw_options) { { 'banish' => false, 'mouseover' => true, 'always' => false } }
      it { expect(subject.send(:always_disabled?)).to be false }
    end
  end

  describe 'mode functionality' do
    context 'in col mode' do
      it { expect(subject.send(:col?)).to be true }
      it { expect(subject.send(:row?)).to be false }
    end

    context 'in row mode' do
      let(:mode) { 'row' }
      it { expect(subject.send(:row?)).to be true }
      it { expect(subject.send(:col?)).to be false }
    end
  end

  describe 'title methods' do
    it { is_expected.to respond_to(:banish_title) }
    it { is_expected.to respond_to(:mouseover_title) }
    it { is_expected.to respond_to(:always_title) }
  end

  describe 'complex state interactions' do
    context 'with all options enabled' do
      let(:default_nsfw_options) { { 'banish' => false, 'mouseover' => true, 'always' => true } }
      it { expect(subject.send(:banish?)).to be false }
      it { expect(subject.send(:mouseover?)).to be true }
      it { expect(subject.send(:always?)).to be true }
      it { expect(subject.send(:banish_disabled?)).to be false }
      it { expect(subject.send(:mouseover_disabled?)).to be false }
      it { expect(subject.send(:always_disabled?)).to be false }
    end

    context 'with banish enabled' do
      let(:default_nsfw_options) { { 'banish' => true, 'mouseover' => false, 'always' => false } }
      it { expect(subject.send(:banish?)).to be true }
      it { expect(subject.send(:mouseover?)).to be false }
      it { expect(subject.send(:always?)).to be false }
      it { expect(subject.send(:banish_disabled?)).to be false }
      it { expect(subject.send(:mouseover_disabled?)).to be true }
      it { expect(subject.send(:always_disabled?)).to be true }
    end
  end
end
