# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobProgress do

  describe '.begin!' do
    subject(:progress) { described_class.begin!('k', label: 'Job K', total: 50) }

    it { expect(progress).to be_persisted }
    it { expect(progress.total).to eq 50 }
    it { expect(progress.completed).to eq 0 }
    it { expect(progress.status).to eq 'running' }
    it { expect(progress.started_at).to be_present }

    it 'upserts by key (a re-run resets the same row)' do
      described_class.begin!('k', label: 'Job K', total: 50).update!(completed: 20)
      expect { described_class.begin!('k', label: 'Job K', total: 30) }.to_not change { described_class.count }
    end

    it 'resets counts on re-run' do
      described_class.begin!('k', label: 'Job K', total: 50).update!(completed: 20, status: 'finished')
      expect(described_class.begin!('k', label: 'Job K', total: 30).completed).to eq 0
    end
  end

  describe '#advance!' do
    let(:progress) { described_class.begin!('k', label: 'Job K', total: 4) }
    it { expect { progress.advance! }.to change { progress.completed }.from(0).to(1) }
  end

  describe '#finish!' do
    let(:progress) { described_class.begin!('k', label: 'Job K', total: 4) }
    it { expect { progress.finish! }.to change { progress.status }.to('finished') }
    it { expect { progress.finish!(status: 'failed') }.to change { progress.status }.to('failed') }
  end

  describe '#percent' do
    it { expect(described_class.new(total: 4, completed: 1).percent).to eq 25 }
    it { expect(described_class.new(total: 0, completed: 0).percent).to eq 0 }
  end
end
