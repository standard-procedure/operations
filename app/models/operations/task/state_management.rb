module Operations::Task::StateManagement
  extend ActiveSupport::Concern

  included do
    attribute :state, :string
    validate :state_is_valid
  end

  class_methods do
    def inputs(*names) = @required_inputs = names.map(&:to_sym)

    def required_inputs = @required_inputs ||= []

    def starts_with(value) = @initial_state = value.to_sym

    def initial_state = @initial_state

    def decision(name, &config) = state_handlers[name.to_sym] = DecisionHandler.new(name, &config)

    def action(name, &handler) = state_handlers[name.to_sym] = ActionHandler.new(name, &handler)

    def result(name, &results) = state_handlers[name.to_sym] = CompletionHandler.new(name, &results)

    def state_handlers = @state_handlers ||= {}

    def handler_for(state) = state_handlers[state.to_sym]

    def required_inputs_are_present_in?(data) = missing_inputs_from(data).empty?

    def missing_inputs_from(data) = (required_inputs - data.keys.map(&:to_sym))
  end

  private def handler_for(state) = self.class.handler_for(state.to_sym)
  private def process_current_state(data)
    handler_for(state).call(self, data)
  rescue => ex
    update! status: "failed", status_message: ex.message.to_s.truncate(240), results: {failure_message: ex.message, exception_class: ex.class.name, exception_backtrace: ex.backtrace}
  end
  private def state_is_valid
    errors.add :state, :invalid if state.blank? || handler_for(state.to_sym).nil?
  end

  class ActionHandler
    def initialize name, &action
      @name = name.to_sym
      @action = action
    end

    def call(task, data)
      @action.nil? ? task.send(@name, data) : data.instance_exec(&@action)
    end
  end

  class DecisionHandler
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
      result = @condition.nil? ? task.send(@name, data) : data.instance_exec(&@condition)
      next_state = result ? @true_state : @false_state
      next_state.respond_to?(:call) ? data.instance_eval(&next_state) : data.go_to(next_state, data)
    end
  end

  class CompletionHandler
    def initialize name, &handler
      @name = name.to_sym
      @handler = handler
    end

    def call(task, data)
      results = OpenStruct.new
      data.instance_exec(results, &@handler) unless @handler.nil?
      data.complete(results)
    end
  end
end
