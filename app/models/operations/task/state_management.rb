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

    def result(name, &results) = state_handlers[name.to_sym] = CompletionHandler.new(name, &results)

    def state_handlers = @state_handlers ||= {}

    def handler_for(state) = state_handlers[state.to_sym]
  end

  private def handler_for(state) = self.class.handler_for(state.to_sym)
  private def process_current_state(data = {}) = handler_for(state).call(self, data)
  private def state_is_valid
    errors.add :state, :invalid if state.blank? || handler_for(state.to_sym).nil?
  end

  class ActionHandler
    def initialize name, &action
      @name = name.to_sym
      @action = action
    end

    def call(task, data = {})
      @action.nil? ? task.send(@name, data) : task.instance_exec(data, &@action)
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

    def call(task, data = {})
      result = @condition.nil? ? task.send(@name, data) : task.instance_exec(data, &@condition)
      task.go_to(result ? @true_state : @false_state)
    end
  end

  class CompletionHandler
    def initialize name, &handler
      @name = name.to_sym
      @handler = handler
    end

    def call(task, data = {})
      results = {}
      @handler&.call(data, results)
      task.complete(**results)
    end
  end
end
