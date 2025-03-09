class Operations::Task::DataCarrier < OpenStruct
  # go_to method removed to enforce static state transitions

  def fail_with(message) = task.fail_with(message)

  def call(sub_task_class, **data, &result_handler) = task.call(sub_task_class, **data, &result_handler)

  def start(sub_task_class, **data, &result_handler) = task.start(sub_task_class, **data, &result_handler)

  def complete(results) = task.complete(results)

  def inputs(*names)
    missing_inputs = (names.map(&:to_sym) - to_h.keys)
    raise ArgumentError.new("Missing inputs: #{missing_inputs.join(", ")}") if missing_inputs.any?
  end

  def optional(*names) = nil
end
