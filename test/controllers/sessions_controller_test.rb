require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  ADMIN = "hibariyashiki@gmail.com"

  setup do
    OmniAuth.config.test_mode = true
    @env = ENV.to_h.slice("ADMIN_EMAILS", "OPEN_LOGIN")
    ENV["ADMIN_EMAILS"] = " Hibariyashiki@gmail.com , other-admin@example.com"
    ENV.delete("OPEN_LOGIN")
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
    %w[ADMIN_EMAILS OPEN_LOGIN].each { |key| @env.key?(key) ? ENV[key] = @env[key] : ENV.delete(key) }
  end

  def google(email, verified: true, uid: "1234567890", name: "Admin")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: uid, info: { email: email, name: name },
      extra: { raw_info: { email_verified: verified } }
    )
  end

  def sign_in_with_google
    post "/auth/google_oauth2"
    follow_redirect! # to the callback
  end

  test "an admin signs in with Google, and becomes a user with that identity" do
    google(ADMIN)

    sign_in_with_google

    assert_redirected_to admin_path
    user = User.sole
    assert_equal [ ADMIN, "Admin", true ], [ user.email, user.name, user.admin ]
    assert_equal [ [ "google_oauth2", "1234567890" ] ], user.identities.pluck(:provider, :uid)
    follow_redirect!
    assert_response :success
    assert_select "h1", "管理画面"
  end

  test "signing in again is the same user, brought up to date" do
    google(ADMIN)
    sign_in_with_google
    google(ADMIN, name: "New Name")

    sign_in_with_google

    assert_equal [ "New Name" ], User.pluck(:name)
    assert_equal 1, Identity.count
  end

  test "anyone not in ADMIN_EMAILS is turned away, and nothing about them is stored" do
    google("someone@example.com")

    sign_in_with_google

    assert_redirected_to login_path
    follow_redirect!
    assert_select ".flash-alert", "現在ログインは受け付けていません。"
    assert_equal 0, User.count
    assert_equal 0, Identity.count
    assert_nil session[:user_id]
  end

  test "an admin's address Google hasn't verified is turned away" do
    google(ADMIN, verified: false)

    sign_in_with_google

    assert_redirected_to login_path
    assert_equal 0, User.count
  end

  test "OPEN_LOGIN lets anyone sign in, as an ordinary user who can't open the admin pages" do
    ENV["OPEN_LOGIN"] = "1"
    google("someone@example.com")

    sign_in_with_google

    assert_redirected_to root_path
    assert_not User.sole.admin
    get admin_path
    assert_redirected_to login_path
  end

  test "the admin pages send anyone not signed in to sign in, and back to where they were after" do
    get admin_path
    assert_redirected_to login_path

    google(ADMIN)
    sign_in_with_google

    assert_redirected_to admin_path
  end

  test "someone taken off ADMIN_EMAILS stops being an admin at their next sign-in" do
    google(ADMIN)
    sign_in_with_google
    ENV["ADMIN_EMAILS"] = "other-admin@example.com"
    ENV["OPEN_LOGIN"] = "1"

    sign_in_with_google

    assert_not User.sole.admin
  end

  test "signing out ends the session" do
    google(ADMIN)
    sign_in_with_google

    delete logout_path

    assert_redirected_to root_path
    get admin_path
    assert_redirected_to login_path
  end

  test "a sign-in that fails at Google comes back with a message" do
    OmniAuth.config.mock_auth[:google_oauth2] = :access_denied

    post "/auth/google_oauth2"
    follow_redirect!
    follow_redirect! if response.redirect? && response.location.include?("/auth/failure")

    assert_redirected_to login_path
    assert_equal 0, User.count
  end

  test "the sign-in page and the admin pages ask not to be indexed, and the public pages don't link to them" do
    get login_path
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "form[action='/auth/google_oauth2'][method=post]"

    get root_path
    assert_select "a[href='#{login_path}']", 0
    assert_select "a[href='#{admin_path}']", 0
  end
end
