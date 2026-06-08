ENV["RAILS_ENV"] ||= "test"
ENV["BUNNY_STORAGE_ENDPOINT"] ||= "https://storage.example.test"
ENV["BUNNY_STORAGE_ACCESS_KEY_ID"] ||= "test-key-id"
ENV["BUNNY_STORAGE_SECRET_ACCESS_KEY"] ||= "test-secret"
ENV["BUNNY_STORAGE_REGION"] ||= "de"
ENV["BUNNY_STORAGE_BUCKET"] ||= "austrian-rocks-test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
