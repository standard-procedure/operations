class Operations::Task::StateManagement::WaitHandler
  def initialize name, &config
    @name = name.to_sym
    @conditions = []
    @destinations = []
    instance_eval(&config)
    puts "Configured"
  end

  def condition(&condition) = @conditions << condition

  def go_to(state) = @destinations << state

  def call(task, data)
    raise Operations::CannotWaitInForeground.new("#{task.class} cannot wait in the foreground", task) unless task.background?
    puts "Searching"
    condition = @conditions.find { |condition| data.instance_eval(&condition) }
    if condition.nil?
      puts "None"
      data.go_to task.state
    else
      index = @conditions.index condition
      puts "Found #{@destinations[index]}"
      data.go_to @destinations[index]
    end
  end
end
