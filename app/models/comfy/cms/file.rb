# frozen_string_literal: true

class Comfy::Cms::File < ActiveRecord::Base

  self.table_name = "comfy_cms_files"

  include Comfy::Cms::WithCategories

  # Rails-8-friendly Libvips variant syntax
  VARIANT_SIZE = {
    redactor: { resize_to_fill: [100, 75] },
    thumb:    { resize_to_fill: [200, 150] },
    icon:     { resize_to_fill: [28, 28] }
  }.freeze

  # temporary place to store attachment
  attr_accessor :file

  has_one_attached :attachment

  # -- Relationships -----------------------------------------------------------
  belongs_to :site

  # -- Callbacks ---------------------------------------------------------------
  before_validation :assign_label, on: :create
  before_create :assign_position
  before_save :process_attachment

  # -- Validations -------------------------------------------------------------
  validates :label, presence: true
  validates :file, presence: true, on: :create

  # -- Scopes ------------------------------------------------------------------
  # When we need to grab only files with image attachments.
  # Don't forget to include `with_attached_attachment` before calling this
  scope :with_images, -> {
    where("active_storage_blobs.content_type LIKE 'image/%'").references(:blob)
  }

protected

  def assign_position
    max = Comfy::Cms::File.maximum(:position)
    self.position = max ? max + 1 : 0
  end

  # TODO: Change db schema not to set blank string
  def assign_label
    return if label.present?
    self.label = file&.original_filename
  end

  def process_attachment
    return if @file.blank?

    # Convert HEIC/HEIF to JPEG for browser compatibility
    @file = convert_heic_to_jpeg(@file) if heic_file?(@file)

    # In test environment, detach any existing problematic attachments first
    if Rails.env.test? && attachment.attached?
      begin
        attachment.blob.content_type
      rescue ActiveStorage::FileNotFoundError
        attachment.detach
      end
    end

    attachment.attach(@file)
  end

  def heic_file?(file)
    return false unless file

    content_type = file.respond_to?(:content_type) ? file.content_type : nil
    filename = file.respond_to?(:original_filename) ? file.original_filename : nil

    content_type&.include?("heic") ||
      content_type&.include?("heif") ||
      filename&.downcase&.end_with?(".heic", ".heif")
  end

  def convert_heic_to_jpeg(file)
    require "image_processing/vips"

    converted = ImageProcessing::Vips
      .source(file.tempfile.path)
      .convert("jpeg")
      .saver(quality: 90)
      .call

    new_filename = file.original_filename.sub(/\.hei[cf]$/i, ".jpg")

    ActionDispatch::Http::UploadedFile.new(
      tempfile: converted,
      filename: new_filename,
      type: "image/jpeg"
    )
  end

end
