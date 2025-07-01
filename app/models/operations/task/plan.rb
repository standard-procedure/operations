module Operations::Task::Plan
  extend ActiveSupport::Concern

  included do
    validate :current_state_is_legal
  end

  class_methods do
    def starts_with(value) = @initial_state = value.to_s

    def action(name, &handler) = state_handlers[name.to_s] = ActionHandler.new(name, &handler)

    def decision(name, &config) = state_handlers[name.to_s] = DecisionHandler.new(name, &config)

    def result(name) = state_handlers[name.to_s] = ResultHandler.new(name)

    def go_to(state)
      # Get the most recently defined action handler
      last_action = state_handlers.values.reverse.find { |h| h.is_a?(ActionHandler) }
      raise ArgumentError, "No action handler defined yet" unless last_action

      last_action.next_state = state.to_sym
    end

    def initial_state = @initial_state || "start"

    def state_handlers = @state_handlers ||= {}

    def handler_for(state) = state_handlers[state.to_s]
  end

  private def handler_for(state) = self.class.handler_for(state)
  private def current_state_is_legal
    errors.add :current_state, :invalid if current_state.blank? || handler_for(current_state).nil?
  end
end
