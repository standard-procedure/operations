module Operations
  class Task < ApplicationRecord
    include StateManagement
    include Deletion
    include Testing
    include Background
    extend InputValidation

    enum :status, in_progress: 0, waiting: 10, completed: 100, failed: -1
    serialize :data, coder: Operations::GlobalIDSerialiser, type: Hash, default: {}
    serialize :results, coder: Operations::GlobalIDSerialiser, type: Hash, default: {}

    # Returns a hash representation of the task's structure
    # Useful for exporting to different formats (e.g., GraphViz)
    def self.to_h
      {
        name: name,
        initial_state: initial_state,
        inputs: required_inputs,
        optional_inputs: optional_inputs,
        states: state_handlers.transform_values { |handler| handler_to_h(handler) }
      }
    end

    private_class_method def self.handler_to_h(handler)
      case handler
      when StateManagement::DecisionHandler
        {
          type: :decision,
          transitions: decision_transitions(handler),
          inputs: extract_inputs(handler),
          optional_inputs: extract_optional_inputs(handler)
        }
      when StateManagement::ActionHandler
        {
          type: :action,
          next_state: handler.next_state,
          inputs: extract_inputs(handler),
          optional_inputs: extract_optional_inputs(handler)
        }
      when StateManagement::WaitHandler
        {
          type: :wait,
          transitions: wait_transitions(handler),
          inputs: extract_inputs(handler),
          optional_inputs: extract_optional_inputs(handler)
        }
      when StateManagement::CompletionHandler
        {
          type: :result,
          inputs: extract_inputs(handler),
          optional_inputs: extract_optional_inputs(handler)
        }
      else
        {
          type: :unknown
        }
      end
    end

    private_class_method def self.extract_inputs(handler)
      handler.instance_variable_defined?(:@required_inputs) ? handler.instance_variable_get(:@required_inputs) : []
    end

    private_class_method def self.extract_optional_inputs(handler)
      handler.instance_variable_defined?(:@optional_inputs) ? handler.instance_variable_get(:@optional_inputs) : []
    end

    private_class_method def self.decision_transitions(handler)
      if handler.instance_variable_defined?(:@true_state) && handler.instance_variable_defined?(:@false_state)
        {
          "true" => handler.instance_variable_get(:@true_state),
          "false" => handler.instance_variable_get(:@false_state)
        }
      else
        handler.instance_variable_get(:@destinations).map.with_index { |dest, i| [:"condition_#{i}", dest] }.to_h
      end
    end

    private_class_method def self.wait_transitions(handler)
      handler.instance_variable_get(:@destinations).map.with_index { |dest, i| [:"condition_#{i}", dest] }.to_h
    end

    def call sub_task_class, **data, &result_handler
      sub_task = sub_task_class.call(**data)
      result_handler&.call(sub_task.results)
      sub_task.results
    end

    def start sub_task_class, **data, &result_handler
      sub_task_class.start(**data)
    end

    def perform
      timeout!
      in_progress!
      handler_for(state).call(self, carrier_for(data))
    rescue => ex
      update! status: "failed", status_message: ex.message.to_s.truncate(240), results: {failure_message: ex.message, exception_class: ex.class.name, exception_backtrace: ex.backtrace}
      raise ex
    end

    def perform_later
      waiting!
      TaskRunnerJob.set(wait_until: background_delay.from_now).perform_later self
    end

    def self.call(**)
      build(background: false, **).tap do |task|
        task.perform
      end
    end

    def self.start(**data)
      build(background: true, **with_timeout(data)).tap do |task|
        task.perform_later
      end
    end

    def go_to(state, data = {}, message: nil)
      update!(state: state, data: data.to_h, status_message: (message || state).to_s.truncate(240))
      background? ? perform_later : perform
    end

    def fail_with(message)
      update! status: "failed", status_message: message.to_s.truncate(240), results: {failure_message: message.to_s}
      raise Operations::Failure.new(message, self)
    end

    def complete(results) = update!(status: "completed", status_message: "completed", results: results.to_h)

    private def carrier_for(data) = data.is_a?(DataCarrier) ? data : DataCarrier.new(data.merge(task: self))

    def self.build(background:, **data)
      validate_inputs! data
      create!(state: initial_state, status: background ? "waiting" : "in_progress", data: data, status_message: "", background: background)
    end
  end
end
