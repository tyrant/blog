# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobProgressReporting do
  let(:klass) do
    Class.new do
      include JobProgressReporting
      def perform(&block)
        with_progress('dummy', label: 'Dummy', total: 3, &block)
      end
    end
  end

  let(:progress) { JobProgress.find_by(key: 'dummy') }

  it 'marks the progress finished on success' do
    klass.new.perform { |p| p.advance! }
    expect(progress.status).to eq 'finished'
  end

  it 'advances within the block' do
    klass.new.perform { |p| 2.times { p.advance! } }
    expect(progress.completed).to eq 2
  end

  describe 'on error' do
    it 're-raises' do
      expect { klass.new.perform { raise 'boom' } }.to raise_error('boom')
    end

    it 'marks the progress failed' do
      klass.new.perform { raise 'boom' } rescue nil
      expect(progress.status).to eq 'failed'
    end
  end
end
