FactoryBot.define do
  factory :fragment, class: 'Comfy::Cms::Fragment' do
    identifier { 'content' }
    tag        { 'wysiwyg' }
    content    { 
      <<~HEREDOC
        #{Faker::Boolean.boolean(true_ratio: 0.7) ? "<p><img src='http://lorempixel.com/#{Faker::Number.between(from: 300, to: 600)}/#{Faker::Number.between(from: 200, to: 450)}/' /></p>" : ""}
        #{(2..8).map { "<p>#{Faker::Lorem.paragraph(sentence_count: Faker::Number.between(from: 1, to: 20))}</p>" }.join}
      HEREDOC
    }
  end
end