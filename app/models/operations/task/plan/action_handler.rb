class Operations::Task::Plan::ActionHandler
  attr_accessor :next_state

  def initialize name, &action
    @name = name.to_sym
    @action = action
    @next_state = nil
  end

  def then next_state
    @next_state = next_state
  end

  def immediate? = true

  def call(task)
    task.instance_exec(&@action)
    task.go_to @next_state
  end
end
