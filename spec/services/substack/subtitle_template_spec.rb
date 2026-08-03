# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::SubtitleTemplate do
  describe '.render' do
    it 'substitutes a token with a value from its array' do
      expect(described_class.render('Hi {{ name }}', { 'name' => ['there'] })).to eq 'Hi there'
    end

    it 'substitutes every token' do
      expect(described_class.render('{{ a }}-{{ b }}', { 'a' => ['1'], 'b' => ['2'] })).to eq '1-2'
    end

    it 'picks a value from the array (single deterministic member repeated)' do
      expect(described_class.render('{{ x }} {{ x }}', { 'x' => ['z'] })).to eq 'z z'
    end

    it 'tolerates whitespace inside the braces' do
      expect(described_class.render('{{x}} {{   x   }}', { 'x' => ['q'] })).to eq 'q q'
    end

    it 'always renders a value drawn from the array' do
      results = Array.new(30) { described_class.render('{{ x }}', { 'x' => %w[a b c] }) }
      expect(results.uniq).to all(be_in(%w[a b c]))
    end

    it 'leaves a token whose variable is missing' do
      expect(described_class.render('a {{ missing }} b', {})).to eq 'a {{ missing }} b'
    end

    it 'leaves a token whose array is empty' do
      expect(described_class.render('{{ x }}', { 'x' => [] })).to eq '{{ x }}'
    end

    it 'leaves a token whose value is not an array' do
      expect(described_class.render('{{ x }}', { 'x' => 'nope' })).to eq '{{ x }}'
    end

    it 'returns plain templates unchanged' do
      expect(described_class.render('No variables here', { 'x' => ['y'] })).to eq 'No variables here'
    end

    it 'treats non-hash variables as empty' do
      expect(described_class.render('{{ x }}', nil)).to eq '{{ x }}'
    end

    it 'upper-cases the compliment variable value' do
      expect(described_class.render('{{ compliment }}', { 'compliment' => ['lovely'] })).to eq 'LOVELY'
    end

    it 'does not upper-case other variables' do
      expect(described_class.render('{{ other }}', { 'other' => ['lovely'] })).to eq 'lovely'
    end
  end
end
