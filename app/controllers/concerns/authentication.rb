# Who is signed in (SessionsController signs people in and out), for any
# controller and its views.
module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  # For the admin pages: anyone else is sent to sign in, and brought back here
  # once they have.
  def require_admin
    return if current_user&.admin?

    session[:return_to] = request.fullpath if request.get? || request.head?
    redirect_to login_path
  end
end
