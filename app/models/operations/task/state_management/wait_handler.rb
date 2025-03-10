class Operations::Task::StateManagement::WaitHandler
  def initialize name, &config
    @name = name.to_sym
    @conditions = []
    @destinations = []
    instance_eval(&config)
  end

  def condition(options = {}, &condition)
    @conditions << condition
    @condition_labels ||= {}
    condition_index = @conditions.size - 1
    @condition_labels[condition_index] = options[:label] if options[:label]
  end

  def go_to(state) = @destinations << state

  def condition_labels = @condition_labels ||= {}

  def call(task, data)
    raise Operations::CannotWaitInForeground.new("#{task.class} cannot wait in the foreground", task) unless task.background?
    condition = @conditions.find { |condition| data.instance_eval(&condition) }
    next_state = (condition.nil? || @conditions.index(condition).nil?) ? task.state : @destinations[@conditions.index(condition)]
    data.go_to next_state
  end
end
