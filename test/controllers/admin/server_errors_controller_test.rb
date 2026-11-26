require "test_helper"

class Admin::ServerErrorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server_error = ServerError.create!(
      fingerprint: "abc", exception_class: "ActiveRecord::ConnectionTimeoutError", message: "could not obtain a connection",
      controller_action: "games#index", request_method: "GET", path: "/games?page=3", user_agent: "Bot/1.0",
      backtrace: "app/controllers/games_controller.rb:12:in 'index'", occurrences: 1234,
      first_seen_at: Time.utc(2026, 11, 22, 0, 0), last_seen_at: Time.utc(2026, 11, 26, 3, 30)
    )
  end

  test "only admins can see the errors" do
    get admin_server_errors_path
    assert_redirected_to login_path

    sign_in(email: "fan@example.com", admin: false)
    get admin_server_error_path(@server_error)
    assert_redirected_to login_path
  end

  test "the list shows each error with its count and latest request, in Tokyo time" do
    sign_in

    get admin_server_errors_path

    assert_response :success
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "table.server-errors td", "1,234"
    assert_select "table.server-errors a[href=?]", admin_server_error_path(@server_error), "ActiveRecord::ConnectionTimeoutError"
    assert_select "table.server-errors code", "GET /games?page=3"
    assert_select "table.server-errors td", "2026-11-26 12:30"
  end

  test "an error's page shows its backtrace, and deleting it takes it off the list" do
    sign_in

    get admin_server_error_path(@server_error)
    assert_response :success
    assert_select "pre.server-error-backtrace", /games_controller\.rb:12/
    assert_select "dd", "Bot/1.0"

    delete admin_server_error_path(@server_error)
    assert_redirected_to admin_server_errors_path
    assert_equal 0, ServerError.count
  end

  test "all the errors can be deleted at once" do
    sign_in

    delete destroy_all_admin_server_errors_path

    assert_redirected_to admin_server_errors_path
    assert_equal 0, ServerError.count
  end
end
