class UserMailer < ApplicationMailer

    def welcome_email(user)
        @user = user
        attachments['homer_naked_church.gif'] = File.read('app/assets/images/homer_naked_church.gif')
        mail(to: @user.email, subject: "[BEM VINDO(A) AO CJR CLASS]")
    end

    def forgot_password_email(user)
        @user = user
        attachments['homer_fuck_you.gif'] = File.read('app/assets/images/homer_fuck_you.gif')
        mail(to: @user.email, subject: "[ALTERAR MINHA SENHA]")
    end

    def reset_password_email(user)
        @user = user
        attachments['homer_driving_dope.gif'] = File.read('app/assets/images/homer_driving_dope.gif')
        mail(to: @user.email, subject: "[NOVA SENHA]")
    end

end
