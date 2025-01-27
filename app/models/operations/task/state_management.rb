module Operations::Task::StateManagement
  extend ActiveSupport::Concern

  def go_to(state, message = nil)
    update!(state: state, status_message: message || state.to_s, data: data)
    process_current_state
  end

  def complete(**results) = update! status: "completed", results: results

  included do
    attribute :state, :string
    validate :state_is_valid
  end

  class_methods do
    def start(**data) = create!(data.merge(state: initial_state)).tap { |task| task.send :process_current_state }

    def starts_with(value) = @initial_state = value.to_sym

    def initial_state = @initial_state

    def decision(name, &config) = state_handlers[name.to_sym] = DecisionHandler.new(name, &config)

    def action(name, &handler) = state_handlers[name.to_sym] = ActionHandler.new(name, &handler)

    def ends_with(name, &results) = state_handlers[name.to_sym] = CompletionHandler.new(name, &results)

    def state_handlers = @state_handlers ||= {}

    def handler_for(state) = state_handlers[state.to_sym]
  end

  private def handler_for(state) = self.class.handler_for(state.to_sym)
  private def process_current_state = handler_for(state).call(self)
  private def state_is_valid
    errors.add :state, :invalid if state.blank? || handler_for(state.to_sym).nil?
  end

  class ActionHandler
    def initialize name, &action
      @name = name.to_sym
      @action = action
    end

    def call(task)
      @action.nil? ? task.send(@name) : task.instance_eval(&@action)
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
      result = @condition.nil? ? operation.send(@name) : operation.instance_eval(&@condition)
      operation.go_to result ? @true_state : @false_state
    end
  end

  class CompletionHandler
    def initialize name, &handler
      @name = name.to_sym
      @handler = handler
    end

    def call task
      results = {}
      @handler&.call(results)
      task.complete(**results)
    end
  end
end
