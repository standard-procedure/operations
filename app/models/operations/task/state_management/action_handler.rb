class Operations::Task::StateManagement::ActionHandler
  attr_accessor :next_state

  def initialize name, &action
    @name = name.to_sym
    @required_inputs = []
    @optional_inputs = []
    @action = action
    @next_state = nil
  end

  def call(task, data)
    # Execute the action block in the context of the data carrier
    result = data.instance_exec(&@action)

    # If state hasn't changed (no go_to in the action) and we have a static next_state,
    # perform the transition now
    if @next_state && task.state == @name.to_s
      # Get the current data as a hash to preserve changes made in the action
      current_data = data.to_h

      # If next_state is a symbol that matches an input parameter name, use that parameter's value
      if @required_inputs.include?(@next_state) || @optional_inputs.include?(@next_state)
        target_state = data.send(@next_state)
        task.go_to(target_state, current_data) if target_state
      else
        task.go_to(@next_state, current_data)
      end
    end

    result
  end
end
