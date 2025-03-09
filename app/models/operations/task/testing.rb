module Operations::Task::Testing
  extend ActiveSupport::Concern

  class_methods do
    def handling state, **data, &block
      # Create a task specifically for testing - avoid serialization issues
      task = new(state: state)
      # Use our own test-specific data carrier that has go_to
      data = TestResultCarrier.new(data.merge(task: task))
      
      # Testing doesn't use the database, so handle serialization by overriding task's go_to
      # to avoid serialization errors
      def task.go_to(state, data = {}, message: nil)
        self.state = state
        # Don't call super to avoid serialization
      end
      
      handler_for(state).call(task, data)
      data.completion_results.nil? ? block.call(data) : block.call(data.completion_results)
    end
  end

  # Instead of extending DataCarrier (which no longer has go_to),
  # create a new class with similar functionality but keeps the go_to method for testing
  class TestResultCarrier < OpenStruct
    def go_to(state, message = nil)
      self.next_state = state
      self.status_message = message || next_state.to_s
    end

    def fail_with(message)
      self.failure_message = message
    end

    def inputs(*names)
      missing_inputs = (names.map(&:to_sym) - to_h.keys)
      raise ArgumentError.new("Missing inputs: #{missing_inputs.join(", ")}") if missing_inputs.any?
    end

    def optional(*names) = nil

    def call(sub_task_class, **data, &result_handler)
      record_sub_task sub_task_class
      # Return mock data for testing
      result = {:answer => 42}
      result_handler&.call(result)
      result
    end

    def start(sub_task_class, **data, &result_handler)
      record_sub_task sub_task_class
      # Just record the sub_task for testing, don't actually start it
      nil
    end

    def complete(results)
      self.completion_results = results
    end

    private def record_sub_task sub_task_class
      self.sub_tasks ||= []
      self.sub_tasks << sub_task_class
    end
  end
end
