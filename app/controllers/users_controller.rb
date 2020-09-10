class UsersController < ApplicationController

    before_action :authorize_request, except: %i[create forgot reset]
    before_action :find_user, except: %i[create index forgot reset]

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
        UserMailer.welcome_email(@user).deliver_later
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

    def forgot
      if params[:email].blank? # check if email is present
        return render json: {error: 'Email not present'}
      end

      user = User.find_by(email: params[:email]) # if present find user by email

      if user.present?
        user.generate_password_token! #generate pass token
        UserMailer.forgot_password_email(user).deliver_later
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

      if user.present? && user.password_token_valid?(params[:token])
        if user.reset_password!(params[:password])
          UserMailer.reset_password_email(user).deliver_later
          render json: {status: 'ok'}, status: :ok
        else
          render json: {error: user.errors.full_messages}, status: :unprocessable_entity
        end
      else
        render json: {error:  ['Link not valid or expired. Try generating a new link.']}, status: :not_found
      end
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
  end