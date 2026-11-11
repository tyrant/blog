# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Substack::ReplyValidator do
  subject(:validator) { described_class.new(count: count, split: split, length: length) }

  let(:count) { 2 }
  let(:split) { 'balanced' }
  let(:length) { 2 }

  def reply(text, stance = 'agree')
    { 'stance' => stance, 'text' => text }
  end

  describe '#reply_problems' do
    subject(:problems) { validator.reply_problems(reply(text)) }

    context 'with a clean reply within the limit' do
      let(:text) { 'Loved this. You made me rethink my mornings.' }

      it { expect(problems).to eq [] }
    end

    context 'with too many sentences' do
      let(:text) { 'One. Two! Three?' }

      it { expect(problems).to eq ['has 3 sentences; the limit is 2'] }
    end

    context 'with closing quotes after a full stop' do
      let(:text) { 'She said "no." Then she left.' }

      it { expect(problems).to eq [] }
    end

    context 'with an ellipsis mid-sentence' do
      let(:text) { 'Well… maybe so. Mostly.' }

      it { expect(problems).to eq [] }
    end

    context 'with a very long single sentence' do
      let(:text) { "#{'word ' * 130}end." }

      it { expect(problems).to eq ['is 654 characters long; the limit is 600'] }
    end

    context 'with a URL' do
      let(:text) { 'See https://example.org for more.' }

      it { expect(problems).to eq ['contains a link'] }
    end

    context 'with a bare domain' do
      let(:text) { 'My recipe is at bonus-recipes.com today.' }

      it { expect(problems).to eq ['contains a link'] }
    end

    context 'with an email address' do
      let(:text) { 'Write to me at sam@example.net anytime.' }

      it { expect(problems).to eq ['contains a link', 'contains an email address'] }
    end

    context 'with an @handle' do
      let(:text) { 'Agree with @mikey on this one.' }

      it { expect(problems).to eq ['contains an @handle'] }
    end
  end

  describe '#set_problems' do
    subject(:problems) { validator.set_problems(replies) }

    context 'with the right count and mix' do
      let(:replies) { [reply('A.', 'agree'), reply('B.', 'disagree')] }

      it { expect(problems).to eq [] }
    end

    context 'with too few replies' do
      let(:replies) { [reply('A.', 'agree')] }

      it { expect(problems).to eq ['I asked for 2 replies and got 1'] }
    end

    context 'when a balanced set is lopsided' do
      let(:count) { 4 }
      let(:replies) { Array.new(3) { reply('A.', 'agree') } + [reply('B.', 'disagree')] }

      it { expect(problems).to eq ['3 agree and 1 disagree, but agreeing and disagreeing replies should be roughly even'] }
    end

    context 'when agree-only has a disagreement' do
      let(:split) { 'agree' }
      let(:replies) { [reply('A.', 'agree'), reply('B.', 'disagree')] }

      it { expect(problems).to eq ['1 agree and 1 disagree, but all of them should agree'] }
    end

    context 'when disagree-only has an agreement' do
      let(:split) { 'disagree' }
      let(:replies) { [reply('A.', 'agree'), reply('B.', 'disagree')] }

      it { expect(problems).to eq ['1 agree and 1 disagree, but all of them should disagree'] }
    end

    context 'when mostly-agree is a tie' do
      let(:split) { 'mostly_agree' }
      let(:replies) { [reply('A.', 'agree'), reply('B.', 'disagree')] }

      it { expect(problems).to eq ['1 agree and 1 disagree, but most of them should agree'] }
    end

    context 'when mostly-disagree is a tie' do
      let(:split) { 'mostly_disagree' }
      let(:replies) { [reply('A.', 'agree'), reply('B.', 'disagree')] }

      it { expect(problems).to eq ['1 agree and 1 disagree, but most of them should disagree'] }
    end
  end
end
