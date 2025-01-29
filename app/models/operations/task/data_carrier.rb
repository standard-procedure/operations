class Operations::Task::DataCarrier < OpenStruct
  def go_to(state, message = nil) = task.go_to(state, self, message)

  def fail_with(message) = task.fail_with(message)

  def complete(results) = task.complete(results)
end
