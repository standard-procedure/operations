module Operations::Agent::Plan
  extend ActiveSupport::Concern

  class_methods do
    def delay(value) = @background_delay = value

    def timeout(value) = @execution_timeout = value

    def on_timeout(&handler) = @on_timeout = handler

    def wait_until(name, &config) = state_handlers[name.to_sym] = Operations::Agent::WaitHandler.new(name, &config)

    def background_delay = @background_delay ||= 5.minutes

    def execution_timeout = @execution_timeout ||= 24.hours

    def timeout_handler = @on_timeout
  end

  def timeout!
    return unless timeout_expired?
    timeout_handler.nil? ? raise(Operations::Timeout.new("Timeout expired", self)) : timeout_handler.call
  end

  private def background_delay = self.class.background_delay
  private def execution_timeout = self.class.execution_timeout
  private def timeout_handler = self.class.timeout_handler
  private def timeout_expired? = times_out_at.present? && times_out_at < Time.now.utc
end
