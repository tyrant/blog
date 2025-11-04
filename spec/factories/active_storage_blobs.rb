FactoryBot.define do
  factory :active_storage_blob, class: 'ActiveStorage::Blob' do
    filename { "test_image_#{SecureRandom.hex(8)}.jpg" }
    content_type { 'image/jpeg' }
    byte_size { 1024 }
    checksum { SecureRandom.base64(27) }
    service_name { 'test' }
    
    # Create the blob record without requiring actual file storage
    after(:build) do |blob|
      blob.key ||= SecureRandom.base58(28)
    end
  end
end
