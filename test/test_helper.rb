ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

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
