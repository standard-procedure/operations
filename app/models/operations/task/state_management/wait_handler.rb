class Operations::Task::StateManagement::WaitHandler
  def initialize name, &config
    @name = name.to_sym
    @conditions = []
    @destinations = []
    instance_eval(&config)
  end

  def condition(destination = nil, options = {}, &condition)
    @conditions << condition
    @destinations << destination if destination
    @condition_labels ||= {}
    condition_index = @conditions.size - 1
    @condition_labels[condition_index] = options[:label] if options[:label]
  end

  def go_to(state) = @destinations << state

  def condition_labels
    @condition_labels ||= {}
  end

  def call(task, data)
    raise Operations::CannotWaitInForeground.new("#{task.class} cannot wait in the foreground", task) unless task.background?
    condition = @conditions.find { |condition| data.instance_eval(&condition) }
    if condition.nil?
      task.go_to(task.state, data.to_h)
    else
      index = @conditions.index condition
      task.go_to(@destinations[index], data.to_h)
    end
  end
end
