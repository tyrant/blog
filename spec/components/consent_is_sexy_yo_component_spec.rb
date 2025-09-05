require 'rails_helper'

RSpec.describe ConsentIsSexyYoComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:default_nsfw_options) { { 'banish' => false, 'mouseover' => false, 'always' => false } }

  describe '#initialize' do
    it 'accepts mode and nsfw_options parameters' do
      component = ConsentIsSexyYoComponent.new(mode: 'col', nsfw_options: default_nsfw_options)
      expect(component).to be_present
    end

    it 'defaults to col mode when not specified' do
      component = ConsentIsSexyYoComponent.new(nsfw_options: default_nsfw_options)
      expect(component.send(:col?)).to be true
      expect(component.send(:row?)).to be false
    end

    it 'accepts row mode' do
      component = ConsentIsSexyYoComponent.new(mode: 'row', nsfw_options: default_nsfw_options)
      expect(component.send(:row?)).to be true
      expect(component.send(:col?)).to be false
    end
  end

  describe 'rendering' do
    it 'renders the component in col mode' do
      render_inline(ConsentIsSexyYoComponent.new(mode: 'col', nsfw_options: default_nsfw_options))
      expect(rendered_component).to be_present
    end

    it 'renders the component in row mode' do
      render_inline(ConsentIsSexyYoComponent.new(mode: 'row', nsfw_options: default_nsfw_options))
      expect(rendered_component).to be_present
    end
  end

  describe 'banish functionality' do
    it 'returns false when banish is not set' do
      component = ConsentIsSexyYoComponent.new(nsfw_options: default_nsfw_options)
      expect(component.send(:banish?)).to be false
    end

    it 'returns true when banish is set' do
      nsfw_options = default_nsfw_options.merge('banish' => true)
      component = ConsentIsSexyYoComponent.new(nsfw_options: nsfw_options)
      expect(component.send(:banish?)).to be true
    end

    it 'is never disabled' do
      component = ConsentIsSexyYoComponent.new(nsfw_options: default_nsfw_options)
      expect(component.send(:banish_disabled?)).to be false
    end
  end

  describe 'mouseover functionality' do
    it 'returns false when mouseover is not set' do
      component = ConsentIsSexyYoComponent.new(nsfw_options: default_nsfw_options)
      expect(component.send(:mouseover?)).to be false
    end

    it 'returns true when mouseover is set' do
      nsfw_options = default_nsfw_options.merge('mouseover' => true)
      component = ConsentIsSexyYoComponent.new(nsfw_options: nsfw_options)
      expect(component.send(:mouseover?)).to be true
    end

    it 'is disabled when banish is true' do
      nsfw_options = default_nsfw_options.merge('banish' => true)
      component = ConsentIsSexyYoComponent.new(nsfw_options: nsfw_options)
      expect(component.send(:mouseover_disabled?)).to be true
    end

    it 'is not disabled when banish is false' do
      component = ConsentIsSexyYoComponent.new(nsfw_options: default_nsfw_options)
      expect(component.send(:mouseover_disabled?)).to be false
    end
  end

  describe 'always functionality' do
    it 'returns false when always is not set' do
      component = ConsentIsSexyYoComponent.new(nsfw_options: default_nsfw_options)
      expect(component.send(:always?)).to be false
    end

    it 'returns true when always is set' do
      nsfw_options = default_nsfw_options.merge('always' => true)
      component = ConsentIsSexyYoComponent.new(nsfw_options: nsfw_options)
      expect(component.send(:always?)).to be true
    end

    it 'is disabled when banish is true' do
      nsfw_options = default_nsfw_options.merge('banish' => true)
      component = ConsentIsSexyYoComponent.new(nsfw_options: nsfw_options)
      expect(component.send(:always_disabled?)).to be true
    end

    it 'is disabled when mouseover is false' do
      nsfw_options = default_nsfw_options.merge('mouseover' => false)
      component = ConsentIsSexyYoComponent.new(nsfw_options: nsfw_options)
      expect(component.send(:always_disabled?)).to be true
    end

    it 'is not disabled when banish is false and mouseover is true' do
      nsfw_options = default_nsfw_options.merge('banish' => false, 'mouseover' => true)
      component = ConsentIsSexyYoComponent.new(nsfw_options: nsfw_options)
      expect(component.send(:always_disabled?)).to be false
    end
  end

  describe 'mode functionality' do
    it 'correctly identifies col mode' do
      component = ConsentIsSexyYoComponent.new(mode: 'col', nsfw_options: default_nsfw_options)
      expect(component.send(:col?)).to be true
      expect(component.send(:row?)).to be false
    end

    it 'correctly identifies row mode' do
      component = ConsentIsSexyYoComponent.new(mode: 'row', nsfw_options: default_nsfw_options)
      expect(component.send(:row?)).to be true
      expect(component.send(:col?)).to be false
    end
  end

  describe 'title methods' do
    it 'has banish_title method' do
      component = ConsentIsSexyYoComponent.new(nsfw_options: default_nsfw_options)
      expect(component).to respond_to(:banish_title)
    end

    it 'has mouseover_title method' do
      component = ConsentIsSexyYoComponent.new(nsfw_options: default_nsfw_options)
      expect(component).to respond_to(:mouseover_title)
    end

    it 'has always_title method' do
      component = ConsentIsSexyYoComponent.new(nsfw_options: default_nsfw_options)
      expect(component).to respond_to(:always_title)
    end
  end

  describe 'complex state interactions' do
    it 'handles all options enabled correctly' do
      nsfw_options = { 'banish' => false, 'mouseover' => true, 'always' => true }
      component = ConsentIsSexyYoComponent.new(nsfw_options: nsfw_options)
      
      expect(component.send(:banish?)).to be false
      expect(component.send(:mouseover?)).to be true
      expect(component.send(:always?)).to be true
      expect(component.send(:banish_disabled?)).to be false
      expect(component.send(:mouseover_disabled?)).to be false
      expect(component.send(:always_disabled?)).to be false
    end

    it 'handles banish enabled state correctly' do
      nsfw_options = { 'banish' => true, 'mouseover' => false, 'always' => false }
      component = ConsentIsSexyYoComponent.new(nsfw_options: nsfw_options)
      
      expect(component.send(:banish?)).to be true
      expect(component.send(:mouseover?)).to be false
      expect(component.send(:always?)).to be false
      expect(component.send(:banish_disabled?)).to be false
      expect(component.send(:mouseover_disabled?)).to be true
      expect(component.send(:always_disabled?)).to be true
    end
  end
end
