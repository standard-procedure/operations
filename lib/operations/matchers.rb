require "rspec/expectations"

# Has the state of the task moved to the expected new state?
#
# Example:
#     expect(test).to have_moved_to "new_state"
#
RSpec::Matchers.matcher :have_moved_to do |state|
  match do |test_result|
    test_result.next_state.to_s == state.to_s
  end
end

# Has the task failed with a given failure message?
#
# Example:
#     expect(test).to have_failed_with "some_error"
#
RSpec::Matchers.matcher :have_failed_with do |failure_message|
  match do |test_result|
    test_result.failure_message.to_s == failure_message.to_s
  end
end
