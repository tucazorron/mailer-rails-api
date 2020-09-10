class User < ApplicationRecord

    has_secure_password
    validates :email, presence: true, uniqueness: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password,
              length: { minimum: 6 },
              if: -> { new_record? || !password.nil? }

    def generate_password_token!
        self.reset_password_token = generate_token
        self.reset_password_sent_at = Time.now.utc
        save!
    end
    
    def password_token_valid?(token)
        (self.reset_password_sent_at + 4.hours) > Time.now.utc && self.reset_password_token == token
    end
    
    def reset_password!(password)
        self.reset_password_token = nil
        self.password = password
        save!
    end
    
    private
    
    def generate_token
        SecureRandom.hex(10)
    end

end
