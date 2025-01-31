class Operations::Task::StateManagement::DecisionHandler
  include Operations::Task::InputValidation

  def initialize name, &config
    @name = name.to_sym
    @condition = nil
    @true_state = nil
    @false_state = nil
    instance_eval(&config)
  end

  def condition(&condition) = @condition = condition

  def if_true(state = nil, &handler) = @true_state = state || handler

  def if_false(state = nil, &handler) = @false_state = state || handler

  def call(task, data)
    validate_inputs! data.to_h
    result = @condition.nil? ? task.send(@name, data) : data.instance_exec(&@condition)
    next_state = result ? @true_state : @false_state
    next_state.respond_to?(:call) ? data.instance_eval(&next_state) : data.go_to(next_state, data)
  end
end
