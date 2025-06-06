class Operations::Task::DataCarrier < OpenStruct
  def fail_with(message) = task.fail_with(message)

  def call(sub_task_class, **data, &result_handler) = task.call(sub_task_class, **data, &result_handler)

  def go_to(state, data = nil) = task.go_to state, data || self

  def complete(results) = task.complete(results)

  def inputs(*names)
    missing_inputs = (names.map(&:to_sym) - to_h.keys)
    raise ArgumentError.new("Missing inputs: #{missing_inputs.join(", ")}") if missing_inputs.any?
  end

  def optional(*names) = nil
end
