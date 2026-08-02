# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubstackSyncConfig do
  describe '#subtitle_for' do
    let(:site) { create :site }
    let(:post) { create :post, site: site }
    let(:config) { described_class.instance.tap { |c| c.update!(subtitle: 'Advice subtitle', subtitle_default: 'Default subtitle') } }

    it 'uses the advice subtitle for Shite Advice posts' do
      BlogPostTag.without_mirror { post.tags << Tag.create!(name: 'Shite Advice') }
      expect(config.subtitle_for(post)).to eq 'Advice subtitle'
    end

    it 'uses the default subtitle otherwise' do
      expect(config.subtitle_for(post)).to eq 'Default subtitle'
    end

    context 'with template variables' do
      let(:config) do
        described_class.instance.tap do |c|
          c.update!(subtitle: 'Advice: {{ x }}', subtitle_default: 'Default: {{ x }}',
                    subtitle_variables_json: '{"x":["only"]}')
        end
      end

      it 'renders the advice template for Shite Advice posts' do
        BlogPostTag.without_mirror { post.tags << Tag.create!(name: 'Shite Advice') }
        expect(config.subtitle_for(post)).to eq 'Advice: only'
      end

      it 'renders the default template otherwise' do
        expect(config.subtitle_for(post)).to eq 'Default: only'
      end
    end
  end

  describe '#subtitle_variables' do
    subject(:config) { described_class.instance }

    it 'parses the JSON into a hash' do
      config.subtitle_variables_json = '{"x":["a","b"]}'
      expect(config.subtitle_variables).to eq('x' => %w[a b])
    end

    it 'is an empty hash when blank' do
      config.subtitle_variables_json = nil
      expect(config.subtitle_variables).to eq({})
    end

    it 'is an empty hash on invalid JSON' do
      config.subtitle_variables_json = 'not json'
      expect(config.subtitle_variables).to eq({})
    end

    it 'is an empty hash when the JSON is not an object' do
      config.subtitle_variables_json = '[1,2,3]'
      expect(config.subtitle_variables).to eq({})
    end
  end

  describe 'validations' do
    subject(:config) { described_class.instance }

    it 'is valid with a nil footer' do
      config.footer_json = nil
      expect(config).to be_valid
    end

    it 'is valid with an array footer' do
      config.footer_json = [{ 'type' => 'button' }]
      expect(config).to be_valid
    end

    it 'is invalid when the footer is not an array' do
      config.footer_json = { 'type' => 'button' }
      expect(config).to_not be_valid
    end

    it 'is invalid with a zero rotation interval' do
      config.quotation_rotation_days = 0
      expect(config).to_not be_valid
    end

    it 'is invalid with a non-integer rotation interval' do
      config.quotation_rotation_days = 1.5
      expect(config).to_not be_valid
    end
  end

  describe '#quotation_rotation_due?' do
    subject(:config) { described_class.instance }

    it 'is due when never rotated' do
      config.quotations_rotated_at = nil
      expect(config.quotation_rotation_due?).to be true
    end

    it 'is due once the interval has elapsed' do
      config.update!(quotation_rotation_days: 7, quotations_rotated_at: 8.days.ago)
      expect(config.quotation_rotation_due?).to be true
    end

    it 'is not due within the interval' do
      config.update!(quotation_rotation_days: 7, quotations_rotated_at: 2.days.ago)
      expect(config.quotation_rotation_due?).to be false
    end
  end

  describe '#footer_json_text' do
    subject(:config) { described_class.instance }

    it 'renders the footer as pretty JSON' do
      config.footer_json = [{ 'type' => 'button' }]
      expect(config.footer_json_text).to eq JSON.pretty_generate([{ 'type' => 'button' }])
    end

    it 'defaults to an empty array when unset' do
      config.footer_json = nil
      expect(config.footer_json_text).to eq "[]"
    end
  end

  describe '#footer_json_text=' do
    subject(:config) { described_class.instance }

    it 'parses valid JSON into footer_json' do
      config.footer_json_text = '[{"type":"button"}]'
      expect(config.footer_json).to eq [{ 'type' => 'button' }]
    end

    it 'marks the record invalid on unparseable JSON' do
      config.footer_json_text = 'not json'
      expect(config).to_not be_valid
    end
  end

  describe 'session health' do
    subject(:config) { described_class.instance }

    describe '#note_session_failure!' do
      it 'flips a healthy session to unhealthy with the message' do
        config.note_session_failure!('cookie rejected (403)')
        expect(config.reload.session_healthy?).to be false
      end

      it 'records the error message' do
        config.note_session_failure!('cookie rejected (403)')
        expect(config.reload.session_error).to eq 'cookie rejected (403)'
      end

      it 'does not write when already unhealthy (transition-only)' do
        config.update_columns(session_healthy: false, session_error: 'old', session_checked_at: 1.day.ago)
        expect { config.note_session_failure!('new') }.to_not change { config.reload.session_error }
      end
    end

    describe '#note_session_recovery!' do
      before { config.update_columns(session_healthy: false, session_error: 'dead', session_checked_at: 1.day.ago) }

      it 'flips an unhealthy session back to healthy' do
        config.note_session_recovery!
        expect(config.reload.session_healthy?).to be true
      end

      it 'clears the error' do
        config.note_session_recovery!
        expect(config.reload.session_error).to be_nil
      end

      it 'does not write when already healthy (transition-only)' do
        config.update_columns(session_healthy: true, session_error: nil, session_checked_at: 1.day.ago)
        expect { config.note_session_recovery! }.to_not change { config.reload.session_checked_at }
      end
    end

    describe '#record_check!' do
      it 'stamps the checked-at time' do
        config.record_check!(healthy: true)
        expect(config.reload.session_checked_at).to be_present
      end

      it 'records an unhealthy check with its error' do
        config.record_check!(healthy: false, error: 'boom')
        expect(config.reload).to have_attributes(session_healthy: false, session_error: 'boom')
      end
    end
  end

  describe '.instance' do
    it { expect(described_class.instance).to be_persisted }

    it 'returns the same singleton row' do
      expect(described_class.instance.id).to eq described_class.instance.id
    end

    it 'creates the singleton even though footer_json is blank' do
      expect { described_class.instance }.to_not raise_error
    end
  end
end
