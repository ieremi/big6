require "test_helper"

class ServerErrorTest < ActiveSupport::TestCase
  def raised(message = "boom")
    raise ArgumentError, message
  rescue ArgumentError => error
    error
  end

  def request(path, user_agent: "Bot/1.0")
    env = Rack::MockRequest.env_for(path, "HTTP_USER_AGENT" => user_agent)
    env["action_dispatch.request.path_parameters"] = { controller: "games", action: "index" }
    ActionDispatch::Request.new(env)
  end

  test "the same error from the same place is one row, counted, with the latest request's details" do
    first = Time.utc(2026, 11, 26, 1, 0)

    ServerError.record(raised, request("/games?page=1"), at: first)
    ServerError.record(raised("bang"), request("/games?page=2", user_agent: "Other/2.0"), at: first + 1.hour)

    assert_equal 1, ServerError.count
    server_error = ServerError.last
    assert_equal 2, server_error.occurrences
    assert_equal "ArgumentError", server_error.exception_class
    assert_equal "games#index", server_error.controller_action
    assert_equal "bang", server_error.message
    assert_equal "/games?page=2", server_error.path
    assert_equal "Other/2.0", server_error.user_agent
    assert_equal first, server_error.first_seen_at
    assert_equal first + 1.hour, server_error.last_seen_at
    assert_includes server_error.backtrace, "server_error_test.rb"
  end

  test "an error raised in another action is a row of its own" do
    ServerError.record(raised, request("/games"))
    other = request("/players")
    other.path_parameters = { controller: "players", action: "index" }
    ServerError.record(raised, other)

    assert_equal 2, ServerError.count
  end
end
