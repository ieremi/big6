# Signing in (with Google, through OmniAuth: config/initializers/omniauth.rb)
# and out. Only those LoginPolicy allows get in; anyone else is told so, and
# nothing about them is stored. Nothing on the public pages links here: an admin
# comes by way of /admin.
class SessionsController < ApplicationController
  # OmniAuth's developer strategy (development only) posts its form back to the
  # callback without the page's CSRF token. Google's callback is a GET, and
  # OmniAuth checks the OAuth state itself.
  skip_forgery_protection only: :create

  before_action { response.set_header("X-Robots-Tag", "noindex, nofollow") }

  def new
    redirect_to admin_path if current_user&.admin?
  end

  def create
    auth = request.env["omniauth.auth"]
    email = auth&.info&.email

    unless auth && LoginPolicy.allowed?(email, verified: verified_email?(auth))
      redirect_to login_path, alert: "現在ログインは受け付けていません。"
      return
    end

    user = User.sign_in_from(auth)
    return_to = session[:return_to]
    reset_session # a new session id at sign-in, so one fixed beforehand is no use
    session[:user_id] = user.id
    redirect_to safe_return_path(return_to) || (user.admin? ? admin_path : root_path), notice: "ログインしました。"
  end

  # OmniAuth sends a sign-in that went wrong here (declined at Google, a
  # mismatched state, ...).
  def failure
    redirect_to login_path, alert: "ログインできませんでした。"
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "ログアウトしました。"
  end

  private

  # Google says whether it has verified the address; the developer strategy
  # (development only) has no such thing.
  def verified_email?(auth)
    case auth.provider
    when "google_oauth2" then auth.extra&.raw_info&.email_verified == true || auth.extra&.raw_info&.email_verified == "true"
    when "developer" then Rails.env.development?
    else false
    end
  end

  # Only a path on this site, never somewhere else a crafted return_to might name.
  def safe_return_path(path)
    path if path.is_a?(String) && path.start_with?("/") && !path.start_with?("//")
  end
end
