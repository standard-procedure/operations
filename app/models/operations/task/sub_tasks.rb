module Operations::Task::SubTasks
  def call sub_task_class, **data, &result_handler
    sub_task = sub_task_class.call(**data)
    result_handler&.call(sub_task.results)
    sub_task.results
  end
end
