# Spec helper for ActiveRecord adapter
require "bundler/setup"

# Load the main Operations V2 gem
require "operations/v2"

# Load the ActiveRecord adapter
require "operations/adapters/storage/active_record"

# Load RSpec
require "rspec"

# Configure RSpec
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Set up in-memory SQLite database for testing
  config.before(:suite) do
    require "active_record"
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )

    # Run migrations
    require_relative "../db/migrate/001_create_operations_tasks"
    CreateOperationsTasks.new.change
  end

  # Reset between tests
  config.before(:each) do
    Operations::TaskRecord.delete_all
  end
end

# Load shared examples from the main gem
# This makes the compatibility suite available to adapter tests
v2_spec_path = File.expand_path("../../../spec/v2/shared_examples", __dir__)
Dir["#{v2_spec_path}/**/*.rb"].each { |f| require f }

# Load custom matchers from main gem
require_relative "../../../spec/v2/v2_spec_helper"
