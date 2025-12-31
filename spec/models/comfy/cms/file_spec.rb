# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Cms::File, type: :model do
  let!(:site) { create(:site) }

  describe 'associations' do
    it { is_expected.to belong_to(:site) }
    it { is_expected.to have_one_attached(:attachment) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:label) }

    context 'on create' do
      it 'validates presence of file' do
        file = build(:comfy_cms_file, site: site, file: nil)
        expect(file).not_to be_valid
        expect(file.errors[:file]).to include("can't be blank")
      end
    end
  end

  describe '#process_attachment' do
    context 'with a standard JPEG file' do
      let(:jpeg_file) { fixture_file_upload('spec/fixtures/files/test_image.jpg', 'image/jpeg') }
      let(:cms_file) { build(:comfy_cms_file, site: site, file: jpeg_file) }

      it 'attaches the file without conversion' do
        cms_file.save!
        expect(cms_file.attachment).to be_attached
        expect(cms_file.attachment.content_type).to eq('image/jpeg')
        expect(cms_file.attachment.filename.to_s).to eq('test_image.jpg')
      end
    end

    context 'with a HEIC file' do
      let(:heic_file) { fixture_file_upload('spec/fixtures/files/test_image.heic', 'image/heic') }
      let(:cms_file) { build(:comfy_cms_file, site: site, file: heic_file) }

      it 'converts HEIC to JPEG' do
        cms_file.save!
        expect(cms_file.attachment).to be_attached
        expect(cms_file.attachment.content_type).to eq('image/jpeg')
        expect(cms_file.attachment.filename.to_s).to eq('test_image.jpg')
      end

      it 'preserves image data after conversion' do
        cms_file.save!
        expect(cms_file.attachment.byte_size).to be > 0
      end
    end

    context 'with a HEIF file' do
      let(:heif_file) { fixture_file_upload('spec/fixtures/files/test_image.heif', 'image/heif') }
      let(:cms_file) { build(:comfy_cms_file, site: site, file: heif_file) }

      it 'converts HEIF to JPEG' do
        cms_file.save!
        expect(cms_file.attachment).to be_attached
        expect(cms_file.attachment.content_type).to eq('image/jpeg')
        expect(cms_file.attachment.filename.to_s).to eq('test_image.jpg')
      end
    end

    context 'with HEIC file detected by extension only' do
      let(:heic_file) { fixture_file_upload('spec/fixtures/files/test_image.heic', 'application/octet-stream') }
      let(:cms_file) { build(:comfy_cms_file, site: site, file: heic_file) }

      it 'converts based on file extension' do
        cms_file.save!
        expect(cms_file.attachment).to be_attached
        expect(cms_file.attachment.content_type).to eq('image/jpeg')
      end
    end
  end

  describe '#heic_file?' do
    let(:cms_file) { build(:comfy_cms_file, site: site) }

    it 'returns true for image/heic content type' do
      file = double(content_type: 'image/heic', original_filename: 'photo.heic')
      expect(cms_file.send(:heic_file?, file)).to be true
    end

    it 'returns true for image/heif content type' do
      file = double(content_type: 'image/heif', original_filename: 'photo.heif')
      expect(cms_file.send(:heic_file?, file)).to be true
    end

    it 'returns true for .heic extension regardless of content type' do
      file = double(content_type: 'application/octet-stream', original_filename: 'photo.HEIC')
      expect(cms_file.send(:heic_file?, file)).to be true
    end

    it 'returns true for .heif extension regardless of content type' do
      file = double(content_type: 'application/octet-stream', original_filename: 'image.HEIF')
      expect(cms_file.send(:heic_file?, file)).to be true
    end

    it 'returns false for JPEG files' do
      file = double(content_type: 'image/jpeg', original_filename: 'photo.jpg')
      expect(cms_file.send(:heic_file?, file)).to be false
    end

    it 'returns false for PNG files' do
      file = double(content_type: 'image/png', original_filename: 'photo.png')
      expect(cms_file.send(:heic_file?, file)).to be false
    end

    it 'returns false for nil' do
      expect(cms_file.send(:heic_file?, nil)).to be false
    end

    it 'handles files without content_type method' do
      file = double(original_filename: 'photo.heic')
      allow(file).to receive(:respond_to?).with(:content_type).and_return(false)
      allow(file).to receive(:respond_to?).with(:original_filename).and_return(true)
      expect(cms_file.send(:heic_file?, file)).to be true
    end
  end

  describe '#convert_heic_to_jpeg' do
    let(:cms_file) { build(:comfy_cms_file, site: site) }
    let(:heic_file) { fixture_file_upload('spec/fixtures/files/test_image.heic', 'image/heic') }

    it 'returns an UploadedFile with JPEG content type' do
      converted = cms_file.send(:convert_heic_to_jpeg, heic_file)
      expect(converted).to be_a(ActionDispatch::Http::UploadedFile)
      expect(converted.content_type).to eq('image/jpeg')
    end

    it 'changes filename extension from .heic to .jpg' do
      converted = cms_file.send(:convert_heic_to_jpeg, heic_file)
      expect(converted.original_filename).to eq('test_image.jpg')
    end

    it 'creates a valid JPEG file' do
      converted = cms_file.send(:convert_heic_to_jpeg, heic_file)
      expect(converted.tempfile.size).to be > 0
    end
  end

  describe '#assign_label' do
    let(:jpeg_file) { fixture_file_upload('spec/fixtures/files/test_image.jpg', 'image/jpeg') }

    it 'assigns label from filename when blank' do
      cms_file = build(:comfy_cms_file, site: site, file: jpeg_file, label: nil)
      cms_file.valid?
      expect(cms_file.label).to eq('test_image.jpg')
    end

    it 'preserves existing label' do
      cms_file = build(:comfy_cms_file, site: site, file: jpeg_file, label: 'Custom Label')
      cms_file.valid?
      expect(cms_file.label).to eq('Custom Label')
    end
  end

  describe '#assign_position' do
    let(:jpeg_file) { fixture_file_upload('spec/fixtures/files/test_image.jpg', 'image/jpeg') }

    it 'assigns position 0 for first file' do
      file1 = create(:comfy_cms_file, site: site, file: jpeg_file)
      expect(file1.position).to eq(0)
    end

    it 'assigns incrementing position for subsequent files' do
      file1 = create(:comfy_cms_file, site: site, file: jpeg_file)
      file2 = create(:comfy_cms_file, site: site, file: jpeg_file)

      expect(file2.position).to eq(file1.position + 1)
    end
  end

  describe 'scopes' do
    describe '.with_images' do
      let(:jpeg_file) { fixture_file_upload('spec/fixtures/files/test_image.jpg', 'image/jpeg') }

      it 'returns files with image content type' do
        image_file = create(:comfy_cms_file, site: site, file: jpeg_file)

        result = Comfy::Cms::File.with_attached_attachment.with_images
        expect(result).to include(image_file)
      end
    end
  end
end
