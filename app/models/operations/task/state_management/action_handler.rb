class Operations::Task::StateManagement::ActionHandler
  def initialize name, inputs = [], optional = [], &action
    @name = name.to_sym
    @required_inputs = inputs
    @optional_inputs = optional
    @action = action
  end

  def call(task, data) = data.instance_exec(&@action)
end
