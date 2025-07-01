class Operations::Task::Plan::ResultHandler
  def initialize name
    @name = name.to_sym
  end

  def immediate? = true

  def call(task) = task.completed!
end
