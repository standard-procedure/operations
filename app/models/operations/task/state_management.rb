module Operations::Task::StateManagement
  extend ActiveSupport::Concern

  included do
    attribute :state, :string
    validate :state_is_valid
  end

  class_methods do
    def starts_with(value) = @initial_state = value.to_sym

    def initial_state = @initial_state

    def decision(name, &config) = state_handlers[name.to_sym] = DecisionHandler.new(name, &config)

    def action(name, &handler) = state_handlers[name.to_sym] = ActionHandler.new(name, &handler)

    def ends_with(name, &results) = state_handlers[name.to_sym] = CompletionHandler.new(name, &results)

    def state_handlers = @state_handlers ||= {}

    def handler_for(state) = state_handlers[state.to_sym]
  end

  private def handler_for(state) = self.class.handler_for(state.to_sym)
  private def state_is_valid
    errors.add :state, :invalid if state.blank? || handler_for(state.to_sym).nil?
  end

  class ActionHandler
    def initialize name, &action
      @name = name.to_sym
      @action = action
    end

    def call(operation)
      @action.nil? ? operation.send(@name) : operation.instance_eval(@action)
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

    def if_true(state) = @true_state = state

    def if_false(state) = @false_state = state

    def call(operation)
      result = @condition.nil? ? operation.send(@name) : operation.instance_eval(@condition)
      operation.go_to result ? @true_state : @false_state
    end
  end

  class CompletionHandler
    def initialize name, &results
      @name = name.to_sym
      @results = results
    end

    def call operation
      results = @results.nil? ? {} : operation.instance_eval(@results)
      operation.complete(**results)
    end
  end
end
