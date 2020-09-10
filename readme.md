# Objetivos da Aula

1. Criar um Usuário no Banco de Dados
2. Testar login de usuário
3. Enviar um email de boas vindas com nome (atributo) do usuário
4. Enviar email com código quando esquecer a senha
5. Enviar email quando senha for alterada
6. Enviar email com diferente passagem de parâmetros junto de um gif na mensagem
7. Dar deploy no Heroku
8. Enviar emails pelo Heroku
9. Utilizar variáveis do ambiente de desenvolvimento do Heroku

# Passo a Passo - Mailer Rails API

1. `rails new --api --database=postgresql -T`
2. `rails g model User name:string email:string password_digest:string`
3. `rails db:setup db:migrate`
4. `user.rb` :
    ```ruby
    has_secure_password
    validates :email, presence: true, uniqueness: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password,
              length: { minimum: 6 },
              if: -> { new_record? || !password.nil? }       
    ```
5. `rails g controller User`
6. `users_controller.rb` :
    ``` ruby
    before_action :authorize_request, except: %i[create]
    before_action :find_user, except: %i[create index]

    def index
        @users = User.all
        render json: @users, status: :ok
    end
  
    def show
        render json: @user, status: :ok
    end
  
    def create
        @user = User.new(user_params)
        if @user.save
            render json: @user, status: :created
        else
            render json: { errors: @user.errors.full_messages },
            status: :unprocessable_entity
        end
    end
  
    def update
        unless @user.update(user_params)
            render json: { errors: @user.errors.full_messages },
            status: :unprocessable_entity
        end
    end
  
    def destroy
        @user.destroy
    end
  
    private
  
    def find_user
        @user = User.find_by_id!(params[:id])
        rescue ActiveRecord::RecordNotFound
        render json: { errors: 'User not found' }, status: :not_found
    end
  
    def user_params
        params.permit(:name, :email, :password, :password_confirmation)
    end
    ```
7. `Gemfile` :
    ``` ruby
    gem 'bcrypt', '~> 3.1.7'
    gem 'jwt'
    ```
8. `bundle install`
9. `app/lib/json_web_token.rb` :
    ``` ruby
    class JsonWebToken
        SECRET_KEY = Rails.application.secrets.secret_key_base. to_s
    
        def self.encode(payload, exp = 24.hours.from_now)
            payload[:exp] = exp.to_i
            JWT.encode(payload, SECRET_KEY)
        end
    
        def self.decode(token)
            decoded = JWT.decode(token, SECRET_KEY)[0]
            HashWithIndifferentAccess.new decoded
        end
    end
    ```
10. `rails g controller Authentication`
11. `authetication_controller.rb` :
    ``` ruby
    class AuthenticationController < ApplicationController

        before_action :authorize_request, except: :login
    
        def login
            @user = User.find_by_email(params[:email])
            if @user&.authenticate(params[:password])
                token = JsonWebToken.encode(user_id: @user.id)
                time = Time.now + 24.hours.to_i
                render json: { token: token, exp: time.strftime("%m-%d-%Y %H:%M"),
                            id: @user.id }, status: :ok
            else
                render json: { error: 'unauthorized' }, status: :unauthorized
            end
        end
    
        private
    
        def login_params
            params.permit(:email, :password)
        end
        
    end
    ```
12. `application_controller.rb` :
    ``` ruby
    def not_found
      render json: { error: 'not_found' }
    end
  
    def authorize_request
      header = request.headers['Authorization']
      header = header.split(' ').last if header
      begin
        @decoded = JsonWebToken.decode(header)
        @current_user = User.find(@decoded[:user_id])
      rescue ActiveRecord::RecordNotFound => e
        render json: { errors: e.message }, status: :unauthorized
      rescue JWT::DecodeError => e
        render json: { errors: e.message }, status: :unauthorized
      end 
    end
    ```
13. `routes.rb` :
    ``` ruby
    resources :users
    post "auth/login", to: "authentication#login"
    ```
14. `rails s`
15. Testar no Insomnia (cadastro funcionando junto do login)
16. `rails g mailer UserMailer`
17. `user_mailer.rb` :
    ``` ruby
    def welcome_email(user)
        @user = user
        mail(to: @user.email, subject: "[BEM VINDO(A) AO CJR CLASS]")
    end
    ```
18. `views/user_mailer/welcome_email.html.erb` :
    ``` html
    <h1>Seja Bem Vindo(a) ao CJR Class</h1>

    <p>Você acabou de se cadastrar no nosso Mailer com o nome de: "<%= @user.name %>".</p>
    ```
19. `users_controller.rb # create` :
    ``` ruby
    UserMailer.welcome_email(@user).deliver_now
    ```
20. `development.rb` :
    ``` ruby
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
        address:              'smtp.gmail.com',
        port:                 587,
        domain:               'cjr.org.br',
        user_name:            'tucazorron@gmail.com',
        password:             'xxxxxxxx',
        authentication:       'plain',
        enable_starttls_auto: true  }
    ```
21. `application_mailer.rb` :
    ``` ruby
    default from: 'tucazorron@gmail.com'
    ```
22. Testar no Insomnia (vai dar certo mas o email não chega)
23. Configurar no Google que Aplicativos menos seguros tenham acesso ao email
24. `rails db:reset`
25. Testar no Insomnia (email vai chegar)
26. `rails g migration AddPasswordResetColumnsToUser reset_password_token:string reset_password_sent_at:datetime`
27. `rails db:migrate`
28. `users_controller.rb` :
    ``` ruby
    def forgot
      if params[:email].blank?
        return render json: {error: 'Email not present'}
      end

      user = User.find_by(email: params[:email])

      if user.present?
        user.generate_password_token!
        render json: {status: 'ok'}, status: :ok
      else
        render json: {error: ['Email address not found. Please check and try again.']}, status: :not_found
      end
    end

    def reset
      token = params[:token].to_s
      email = params[:email]

      if token.blank?
        return render json: {error: 'Token not present'}
      end

      if email.blank?
        return render json: {error: 'Email not present'}
      end

      user = User.find_by(email: params[:email])

      if user.present? && user.password_token_valid?
        if user.reset_password!(params[:password])
          render json: {status: 'ok'}, status: :ok
        else
          render json: {error: user.errors.full_messages}, status: :unprocessable_entity
        end
      else
        render json: {error:  ['Link not valid or expired. Try generating a new link.']}, status: :not_found
      end
    end
    ```
29. `users_controller.rb` :
    ``` ruby
    before_action :authorize_request, except: %i[create forgot reset]
    before_action :find_user, except: %i[create index forgot reset]
    ```
30. `user.rb` :
    ``` ruby
    def generate_password_token!
        self.reset_password_token = generate_token
        self.reset_password_sent_at = Time.now.utc
        save!
    end
    
    def password_token_valid?
        (self.reset_password_sent_at + 4.hours) > Time.now.utc
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
    ```
31. `routes.rb` :
    ``` ruby
    post "login/forgot_password", to: "users#forgot"
    post "login/reset_password", to: "users#reset"
    ```
32. `user_mailer.rb` :
    ``` ruby
    def forgot_password_email(user)
        @user = user
        mail(to: @user.email, subject: "[ALTERAR MINHA SENHA]")
    end

    def reset_password_email(user)
        @user = user
        mail(to: @user.email, subject: "[NOVA SENHA]")
    end
    ```
33. `views/user_mailer/forgot_password_email.html.erb` :
    ``` html
    <h1>Código para Alterar a sua Senha: <%= @user.reset_password_token %></h1>
    ```
34. `views/user_mailer/reset_password_email.html.erb` :
    ``` html
    <h1>Senha alterada com Sucesso</h1>
    ```
35. `users_controller.rb` :
    ``` ruby
    def forgot

    ...

    UserMailer.forgot_password_email(user).deliver_now

    ...

    def reset

    ...

    UserMailer.reset_password_email(user).deliver_now
    ```
36. Testar no Insomnia (vai dar certo)
37. Mandar email com imagem com outra passagem de parâmetros e `deliver_later`
38. `users_controller.rb` :
    ``` ruby
    def create
    
    ...

    UserMailer.with(user: @user).welcome_email.deliver_later
    ```
39. `user_mailer.rb` :
    ``` ruby
    def welcome_email

    ...

    attachments['homer.gif'] = File.read('app/assets/images/homer.gif')
    ```
40. `welcome_email.html.erb` :
    ``` html
    <%= image_tag attachments['homer.gif'].url, alt: 'Homer Pelado', class: 'photos' %>
    ```
41. `production.rb` :
    ``` ruby
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
        address:              'smtp.gmail.com',
        port:                 587,
        domain:               'cjr.org.br',
        user_name:            ENV["DEFAULT_EMAIL"],
        password:             ENV["DEFAULT_PASSWORD"],
        authentication:       'plain',
        enable_starttls_auto: true  }
42. Adicionar um repositório no git e enviar para lá
43. `heroku login`
44. `heroku create nome-do-projeto`
45. `git push heroku master`
46. `heroku run rails db:migrate`
47. Setar as variáveis de ambiente de desenvolvimento no Heroku
