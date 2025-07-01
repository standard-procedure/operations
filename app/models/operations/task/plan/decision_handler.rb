class Operations::Task::Plan::DecisionHandler
  include Operations::Task::InputValidation

  def initialize name, &config
    @name = name.to_sym
    @conditions = []
    @destinations = []
    @true_state = nil
    @false_state = nil
    instance_eval(&config)
  end

  def immediate? = true

  def condition(&condition)
    @conditions << condition
  end

  def go_to(destination) = @destinations << destination

  def if_true(state = nil, &handler) = @true_state = state || handler

  def if_false(state = nil, &handler) = @false_state = state || handler

  def call(task)
    has_true_false_handlers? ? handle_single_condition(task) : handle_multiple_conditions(task)
  end

  private def has_true_false_handlers? = !@true_state.nil? || !@false_state.nil?

  private def handle_single_condition(task)
    next_state = task.instance_eval(&@conditions.first) ? @true_state : @false_state
    task.go_to(next_state)
  end

  private def handle_multiple_conditions(task)
    condition = @conditions.find { |condition| task.instance_eval(&condition) }
    raise Operations::NoDecision.new("No conditions matched #{@name}") if condition.nil?
    index = @conditions.index condition
    task.go_to(@destinations[index])
  end
end
