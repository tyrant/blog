# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comfy::Cms::File, type: :model do
  let!(:site) { create :site }
  let(:jpeg_file) { fixture_file_upload('spec/fixtures/files/test_image.jpg', 'image/jpeg') }
  let(:heic_file) { fixture_file_upload('spec/fixtures/files/test_image.heic', 'image/heic') }
  let(:heif_file) { fixture_file_upload('spec/fixtures/files/test_image.heif', 'image/heif') }

  describe 'associations' do
    it { is_expected.to belong_to(:site) }
    it { is_expected.to have_one_attached(:attachment) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:label) }

    context 'on create' do
      let(:cms_file) { build :comfy_cms_file, site: site, file: nil }

      it { expect(cms_file).to_not be_valid }
      it { expect(cms_file.tap(&:valid?).errors[:file]).to include("can't be blank") }
    end
  end

  describe '#process_attachment' do
    context 'with a standard JPEG file' do
      let(:cms_file) { create :comfy_cms_file, site: site, file: jpeg_file }

      it { expect(cms_file.attachment).to be_attached }
      it { expect(cms_file.attachment.content_type).to eq 'image/jpeg' }
      it { expect(cms_file.attachment.filename.to_s).to eq 'test_image.jpg' }
    end

    context 'with a HEIC file' do
      let(:cms_file) { create :comfy_cms_file, site: site, file: heic_file }

      it { expect(cms_file.attachment).to be_attached }
      it { expect(cms_file.attachment.content_type).to eq 'image/jpeg' }
      it { expect(cms_file.attachment.filename.to_s).to eq 'test_image.jpg' }
      it { expect(cms_file.attachment.byte_size).to be > 0 }
    end

    context 'with a HEIF file' do
      let(:cms_file) { create :comfy_cms_file, site: site, file: heif_file }

      it { expect(cms_file.attachment).to be_attached }
      it { expect(cms_file.attachment.content_type).to eq 'image/jpeg' }
      it { expect(cms_file.attachment.filename.to_s).to eq 'test_image.jpg' }
    end

    context 'with HEIC file detected by extension only' do
      let(:heic_octet) { fixture_file_upload('spec/fixtures/files/test_image.heic', 'application/octet-stream') }
      let(:cms_file) { create :comfy_cms_file, site: site, file: heic_octet }

      it { expect(cms_file.attachment).to be_attached }
      it { expect(cms_file.attachment.content_type).to eq 'image/jpeg' }
    end
  end

  describe '#heic_file?' do
    let(:cms_file) { build :comfy_cms_file, site: site }

    context 'with image/heic content type' do
      let(:file) { double(content_type: 'image/heic', original_filename: 'photo.heic') }

      it { expect(cms_file.send(:heic_file?, file)).to be true }
    end

    context 'with image/heif content type' do
      let(:file) { double(content_type: 'image/heif', original_filename: 'photo.heif') }

      it { expect(cms_file.send(:heic_file?, file)).to be true }
    end

    context 'with .heic extension regardless of content type' do
      let(:file) { double(content_type: 'application/octet-stream', original_filename: 'photo.HEIC') }

      it { expect(cms_file.send(:heic_file?, file)).to be true }
    end

    context 'with .heif extension regardless of content type' do
      let(:file) { double(content_type: 'application/octet-stream', original_filename: 'image.HEIF') }

      it { expect(cms_file.send(:heic_file?, file)).to be true }
    end

    context 'with JPEG file' do
      let(:file) { double(content_type: 'image/jpeg', original_filename: 'photo.jpg') }

      it { expect(cms_file.send(:heic_file?, file)).to be false }
    end

    context 'with PNG file' do
      let(:file) { double(content_type: 'image/png', original_filename: 'photo.png') }

      it { expect(cms_file.send(:heic_file?, file)).to be false }
    end

    context 'with nil' do
      it { expect(cms_file.send(:heic_file?, nil)).to be false }
    end

    context 'with file missing content_type method' do
      let(:file) { double(original_filename: 'photo.heic') }

      before do
        allow(file).to receive(:respond_to?).with(:content_type).and_return(false)
        allow(file).to receive(:respond_to?).with(:original_filename).and_return(true)
      end

      it { expect(cms_file.send(:heic_file?, file)).to be true }
    end
  end

  describe '#convert_heic_to_jpeg' do
    let(:cms_file) { build :comfy_cms_file, site: site }
    let(:converted) { cms_file.send(:convert_heic_to_jpeg, heic_file) }

    it { expect(converted).to be_a ActionDispatch::Http::UploadedFile }
    it { expect(converted.content_type).to eq 'image/jpeg' }
    it { expect(converted.original_filename).to eq 'test_image.jpg' }
    it { expect(converted.tempfile.size).to be > 0 }
  end

  describe '#assign_label' do
    context 'when label is blank' do
      let(:cms_file) { build :comfy_cms_file, site: site, file: jpeg_file, label: nil }

      before { cms_file.valid? }

      it { expect(cms_file.label).to eq 'test_image.jpg' }
    end

    context 'when label is present' do
      let(:cms_file) { build :comfy_cms_file, site: site, file: jpeg_file, label: 'Custom Label' }

      before { cms_file.valid? }

      it { expect(cms_file.label).to eq 'Custom Label' }
    end
  end

  describe '#assign_position' do
    context 'for first file' do
      let!(:file1) { create :comfy_cms_file, site: site, file: jpeg_file }

      it { expect(file1.position).to eq 0 }
    end

    context 'for subsequent files' do
      let!(:file1) { create :comfy_cms_file, site: site, file: jpeg_file }
      let!(:file2) { create :comfy_cms_file, site: site, file: jpeg_file }

      it { expect(file2.position).to eq(file1.position + 1) }
    end
  end

  describe 'scopes' do
    describe '.with_images' do
      let!(:image_file) { create :comfy_cms_file, site: site, file: jpeg_file }

      it { expect(Comfy::Cms::File.with_attached_attachment.with_images).to include(image_file) }
    end
  end
end
