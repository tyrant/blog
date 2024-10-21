module Tokens
  class Validator
    include ServiceInterface

    ENCODING = "HS256"
    arguments :token

    def execute
      decoded_token.present?
    rescue JWT::ExpiredSignature
      false
    end

    def decoded_token
      JWT.decode @token, Rails.application.secret_key_base, true, algorithm: ENCODING
    end
  end
end
