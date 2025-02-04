class Operations::Task::StateManagement::WaitHandler
  def initialize name, &config
    @name = name.to_sym
    @next_state = nil
    @condition = nil
    instance_eval(&config)
  end

  def condition(&condition) = @condition = condition

  def go_to(state) = @next_state = state

  def call(task, data)
    raise Operations::CannotWaitInForeground.new("#{task.class} cannot wait in the foreground", task) unless task.background?
    next_state = data.instance_eval(&@condition) ? @next_state : task.state
    data.go_to(next_state)
  end
end
