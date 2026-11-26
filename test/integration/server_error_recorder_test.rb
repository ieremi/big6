require "test_helper"

class ServerErrorRecorderTest < ActionDispatch::IntegrationTest
  test "a request that raises an error is recorded, and the error still goes on" do
    stub_method(Article, :all, -> { raise "broken" }) do
      # The test environment re-raises what isn't a 4xx (show_exceptions: :rescuable).
      assert_raises(RuntimeError) { get articles_path, headers: { "User-Agent" => "Bot/1.0" } }
    end

    server_error = ServerError.sole
    assert_equal "RuntimeError", server_error.exception_class
    assert_equal "broken", server_error.message
    assert_equal "articles#index", server_error.controller_action
    assert_equal "GET", server_error.request_method
    assert_equal "/articles", server_error.path
    assert_equal "Bot/1.0", server_error.user_agent
  end

  test "an error Rails answers with a 4xx is not recorded" do
    get article_path("no-such-article")

    assert_response :not_found
    assert_equal 0, ServerError.count
  end

  test "a failure to record doesn't change the request's error" do
    stub_method(ServerError, :record, ->(*) { raise ActiveRecord::ConnectionTimeoutError }) do
      stub_method(Article, :all, -> { raise "broken" }) do
        assert_raises(RuntimeError) { get articles_path }
      end
    end
  end
end
