require "bundler/setup"
require_relative "../../lib/operations/v2"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed

  # Reset storage between tests
  config.before(:each) do
    Operations::V2.storage = Operations::V2::MemoryStorage.new
    Operations::V2.executor = Operations::V2::InlineExecutor.new
  end
end

# Custom matchers for V2
RSpec::Matchers.define :be_in do |expected_state|
  match do |task|
    task.current_state == expected_state.to_s
  end

  failure_message do |task|
    "expected task to be in state #{expected_state}, but was in #{task.current_state}"
  end
end

RSpec::Matchers.define :be_completed do
  match do |task|
    task.completed?
  end
end

RSpec::Matchers.define :be_failed do
  match do |task|
    task.failed?
  end
end

RSpec::Matchers.define :be_active do
  match do |task|
    task.active?
  end
end

RSpec::Matchers.define :be_waiting do
  match do |task|
    task.waiting?
  end
end
