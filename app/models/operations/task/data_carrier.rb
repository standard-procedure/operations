require "ostruct"

class Operations::Task::DataCarrier < OpenStruct
  def go_to(state, message = nil) = _task.go_to(state, self, message)

  def fail_with(message) = _task.fail_with(message)
end
