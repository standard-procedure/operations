class Operations::Task::StateManagement::WaitHandler
  def initialize name, &config
    @name = name.to_sym
    @conditions = []
    @destinations = []
    instance_eval(&config)
  end

  def condition(&condition) = @conditions << condition

  def go_to(state) = @destinations << state

  def call(task, data)
    raise Operations::CannotWaitInForeground.new("#{task.class} cannot wait in the foreground", task) unless task.background?
    condition = @conditions.find { |condition| data.instance_eval(&condition) }
    if condition.nil?
      data.go_to task.state
    else
      index = @conditions.index condition
      data.go_to @destinations[index]
    end
  end
end
