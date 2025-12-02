module Operations::Task::Plan
  extend ActiveSupport::Concern

  included do
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

    def queue(value) = @queue_as = value

    def runs_on(value) = @queue_adapter ||= value
    alias_method :runs, :runs_on
    alias_method :runs_using, :runs_on

    def delete_after(value) = @deletion_time = value

    def on_timeout(&handler) = @on_timeout = handler

    def background_delay = @background_delay ||= 1.minute

    def execution_timeout = @execution_timeout ||= 24.hours

    def queue_as = @queue_as ||= :default

    def queue_adapter = @queue_adapter ||= Operations::WakeTaskJob.queue_adapter

    def timeout_handler = @on_timeout

    def deletion_time = @deletion_time ||= 90.days

    def state_handlers = @state_handlers ||= {}

    def handler_for(state) = state_handlers[state.to_s]

    def interaction_handlers = @interaction_handlers ||= {}

    def interaction_handler_for(name) = interaction_handlers[name.to_s]

    def sleep_times = {wakes_at: background_delay.from_now, expires_at: execution_timeout.from_now, delete_at: deletion_time.from_now}

    def default_times = {wakes_at: Time.now, expires_at: execution_timeout.from_now, delete_at: deletion_time.from_now}
  end

  def in?(state) = current_state == state.to_s
  alias_method :waiting_until?, :in?

  private def handler_for(state) = self.class.handler_for(state)
  private def sleep_times = self.class.sleep_times
  private def default_times = self.class.default_times
  private def background_delay = self.class.background_delay
  private def execution_timeout = self.class.execution_timeout
  private def timeout_handler = self.class.timeout_handler
  private def timeout_expired? = expires_at.present? && expires_at < Time.now.utc
  private def current_state_is_legal
    errors.add :current_state, :invalid if current_state.blank? || handler_for(current_state).nil?
  end
end
