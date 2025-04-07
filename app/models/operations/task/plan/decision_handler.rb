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

  def condition(destination = nil, options = {}, &condition)
    @conditions << condition
    @destinations << destination if destination
    @condition_labels ||= {}
    condition_index = @conditions.size - 1
    @condition_labels[condition_index] = options[:label] if options[:label]
  end

  def go_to(destination) = @destinations << destination

  def condition_labels
    @condition_labels ||= {}
  end

  def if_true(state = nil, &handler) = @true_state = state || handler

  def if_false(state = nil, &handler) = @false_state = state || handler

  def call(task, data)
    validate_inputs! data.to_h
    has_true_false_handlers? ? handle_single_condition(task, data) : handle_multiple_conditions(task, data)
  end

  private def has_true_false_handlers? = !@true_state.nil? || !@false_state.nil?

  private def handle_single_condition(task, data)
    next_state = data.instance_eval(&@conditions.first) ? @true_state : @false_state
    next_state.respond_to?(:call) ? data.instance_eval(&next_state) : data.go_to(next_state, data)
  end

  private def handle_multiple_conditions(task, data)
    condition = @conditions.find { |condition| data.instance_eval(&condition) }
    raise Operations::NoDecision.new("No conditions matched #{@name}") if condition.nil?
    index = @conditions.index condition
    data.go_to(@destinations[index])
  end
end
