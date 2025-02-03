module Operations::Task::Testing
  extend ActiveSupport::Concern

  class_methods do
    def handling state, **data, &block
      task = new state: state
      data = TestResultCarrier.new(data.merge(task: task))
      handler_for(state).call(task, data)
      data.completion_results.nil? ? block.call(data) : block.call(data.completion_results)
    end
  end

  class TestResultCarrier < Operations::Task::DataCarrier
    def go_to(state, message = nil)
      self.next_state = state
      self.status_message = message || next_state.to_s
    end

    def fail_with(message)
      self.failure_message = message
    end

    def complete(results)
      self.completion_results = results
    end
  end
end
