module Operations::Task::Exports
  extend ActiveSupport::Concern
  class_methods do
    # Returns a hash representation of the task's structure
    # Useful for exporting to different formats (e.g., GraphViz)
    def to_h
      {name: name, initial_state: initial_state, inputs: required_inputs, optional_inputs: optional_inputs, states: state_handlers.transform_values { |handler| handler_to_h(handler) }}
    end

    def handler_to_h(handler)
      case handler
      when Operations::Task::StateManagement::DecisionHandler
        {type: :decision, transitions: decision_transitions(handler), inputs: extract_inputs(handler), optional_inputs: extract_optional_inputs(handler)}
      when Operations::Task::StateManagement::ActionHandler
        {type: :action, next_state: handler.next_state, inputs: extract_inputs(handler), optional_inputs: extract_optional_inputs(handler)}
      when Operations::Task::StateManagement::WaitHandler
        {type: :wait, transitions: wait_transitions(handler), inputs: extract_inputs(handler), optional_inputs: extract_optional_inputs(handler)}
      when Operations::Task::StateManagement::CompletionHandler
        {type: :result, inputs: extract_inputs(handler), optional_inputs: extract_optional_inputs(handler)}
      else
        {type: :unknown}
      end
    end

    def extract_inputs(handler)
      handler.instance_variable_defined?(:@required_inputs) ? handler.instance_variable_get(:@required_inputs) : []
    end

    def extract_optional_inputs(handler)
      handler.instance_variable_defined?(:@optional_inputs) ? handler.instance_variable_get(:@optional_inputs) : []
    end

    def decision_transitions(handler)
      if handler.instance_variable_defined?(:@true_state) && handler.instance_variable_defined?(:@false_state)
        {"true" => handler.instance_variable_get(:@true_state), "false" => handler.instance_variable_get(:@false_state)}
      else
        handler.instance_variable_get(:@destinations).map.with_index { |dest, i| [:"condition_#{i}", dest] }.to_h
      end
    end

    def wait_transitions(handler)
      handler.instance_variable_get(:@destinations).map.with_index { |dest, i| [:"condition_#{i}", dest] }.to_h
    end
  end
end
