# V2 Spec Helper - minimal dependencies, no bundler
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "operations/v2"

# Minimal RSpec configuration if RSpec is available
begin
  require "rspec"

  RSpec.configure do |config|
    config.expect_with :rspec do |expectations|
      expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    end

    # Reset storage between tests
    config.before(:each) do
      Operations::V2.storage = Operations::V2::Adapters::Storage::Memory.new
      Operations::V2.executor = Operations::V2::Adapters::Executor::Inline.new
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

rescue LoadError
  puts "RSpec not available - specs will load but not run"
  puts "Install RSpec with: gem install rspec"
end
