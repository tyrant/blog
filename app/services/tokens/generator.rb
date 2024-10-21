module Tokens
  class Generator
    include ServiceInterface

    EXPIRATION_DELAY = 2.months
    ENCODING = "HS256"
    
    arguments expiration_delay: EXPIRATION_DELAY

    def execute
      JWT.encode payload, Rails.application.secret_key_base, ENCODING 
    end

    private

    def payload
      { exp: expiration_time }
    end

    def expiration_time
      (Time.zone.now + @expiration_delay).to_i
    end
  end
end
