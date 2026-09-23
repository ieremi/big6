ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActionDispatch
  class IntegrationTest
    # Signs in through OmniAuth's test mode as an admin (an address put in
    # ADMIN_EMAILS for the block), or as an ordinary user with admin: false
    # (OPEN_LOGIN for the block). Returns the user.
    def sign_in(email: "admin@example.com", admin: true)
      saved = ENV.to_h.slice("ADMIN_EMAILS", "OPEN_LOGIN")
      admin ? ENV["ADMIN_EMAILS"] = email : ENV["OPEN_LOGIN"] = "1"
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        provider: "google_oauth2", uid: "uid-#{email}", info: { email: email, name: email },
        extra: { raw_info: { email_verified: true } }
      )
      post "/auth/google_oauth2"
      follow_redirect!
      User.find_by!(email: email)
    ensure
      OmniAuth.config.mock_auth[:google_oauth2] = nil
      OmniAuth.config.test_mode = false
      %w[ADMIN_EMAILS OPEN_LOGIN].each { |key| saved.key?(key) ? ENV[key] = saved[key] : ENV.delete(key) }
    end
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Replaces a method of one object for the length of the block: with a callable,
    # which gets the arguments the method is called with. (Minitest 6 no longer has
    # minitest/mock's stub.)
    def stub_method(object, name, callable)
      singleton = object.singleton_class
      own = singleton.instance_methods(false).include?(name) || singleton.private_instance_methods(false).include?(name)
      original = singleton.instance_method(name) if own

      singleton.send(:define_method, name) { |*args, **kwargs| kwargs.empty? ? callable.call(*args) : callable.call(*args, **kwargs) }
      yield
    ensure
      singleton.send(:remove_method, name)
      singleton.send(:define_method, name, original) if original
    end
  end
end
