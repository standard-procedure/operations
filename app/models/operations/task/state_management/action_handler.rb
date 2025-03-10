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
    data.instance_exec(&@action).tap do |result|
      data.go_to @next_state unless @next_state.nil?
    end
  end
end
