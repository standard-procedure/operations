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

    def action(name, inputs: [], optional: [], &handler) = state_handlers[name.to_sym] = ActionHandler.new(name, inputs, optional, &handler)

    def wait_until(name, &config) = state_handlers[name.to_sym] = WaitHandler.new(name, &config)

    def result(name, inputs: [], optional: [], &results) = state_handlers[name.to_sym] = CompletionHandler.new(name, inputs, optional, &results)

    def state_handlers = @state_handlers ||= {}

    def handler_for(state) = state_handlers[state.to_sym]
  end

  private def handler_for(state) = self.class.handler_for(state.to_sym)
  private def state_is_valid
    errors.add :state, :invalid if state.blank? || handler_for(state.to_sym).nil?
  end
end
