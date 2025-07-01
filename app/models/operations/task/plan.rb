module Operations::Task::Plan
  extend ActiveSupport::Concern

  included do
    scope :ready_to_wake, -> { ready_to_wake_at(Time.current) }
    scope :ready_to_wake_at, ->(time) { where(wakes_at: ..time) }
    scope :expired, -> { expires_at(Time.current) }
    scope :expired_at, ->(time) { where(expires_at: ..time) }
    scope :ready_to_delete, -> { ready_to_delete_at(Time.current) }
    scope :ready_to_delete_at, ->(time) { where(delete_at: ..time) }
    validate :current_state_is_legal
  end

  class_methods do
    def starts_with(value) = @initial_state = value.to_s

    def action(name, &handler) = state_handlers[name.to_s] = ActionHandler.new(name, &handler)

    def decision(name, &config) = state_handlers[name.to_s] = DecisionHandler.new(name, &config)

    def wait_until(name, &config) = state_handlers[name.to_s] = WaitHandler.new(name, &config)

    def interaction(name, &implementation) = interaction_handlers[name.to_s] = InteractionHandler.new(name, self, &implementation)

    def result(name) = state_handlers[name.to_s] = ResultHandler.new(name)

    def go_to(state)
      # Get the most recently defined action handler
      last_action = state_handlers.values.reverse.find { |h| h.is_a?(ActionHandler) }
      raise ArgumentError, "No action handler defined yet" unless last_action

      last_action.next_state = state.to_sym
    end

    def initial_state = @initial_state || "start"

    def delay(value) = @background_delay = value

    def timeout(value) = @execution_timeout = value

    def delete_after(value) = @deletion_time = value

    def on_timeout(&handler) = @on_timeout = handler

    def background_delay = @background_delay ||= 1.minute

    def execution_timeout = @execution_timeout ||= 24.hours

    def timeout_handler = @on_timeout

    def deletion_time = @deletion_time ||= 90.days

    def state_handlers = @state_handlers ||= {}

    def handler_for(state) = state_handlers[state.to_s]

    def interaction_handlers = @interaction_handlers ||= {}

    def interaction_handler_for(name) = interaction_handlers[name.to_s]

    def default_times = {wakes_at: Time.current + background_delay, expires_at: Time.current + execution_timeout, delete_at: Time.current + deletion_time}
  end

  def in?(state) = current_state == state.to_s
  alias_method :waiting_until?, :in?

  private def handler_for(state) = self.class.handler_for(state)
  private def default_times = self.class.default_times
  private def background_delay = self.class.background_delay
  private def execution_timeout = self.class.execution_timeout
  private def timeout_handler = self.class.timeout_handler
  private def timeout_expired? = expires_at.present? && expires_at < Time.now.utc
  private def call_timeout_handler = timeout_handler.nil? ? raise(Operations::Timeout.new("Timeout expired", self)) : timeout_handler.call
  private def current_state_is_legal
    errors.add :current_state, :invalid if current_state.blank? || handler_for(current_state).nil?
  end
end
