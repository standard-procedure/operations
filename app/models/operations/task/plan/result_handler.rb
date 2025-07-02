class Operations::Task::Plan::ResultHandler
  def initialize name
    @name = name.to_sym
  end

  def immediate? = true

  def call(task) = task.update task_status: "completed", completed_at: Time.current
end
