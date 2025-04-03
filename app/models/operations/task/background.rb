module Operations::Task::Background
  extend ActiveSupport::Concern

  included do
    scope :zombies, -> { zombies_at(Time.now) }
    scope :zombies_at, ->(time) { where(becomes_zombie_at: ..time) }
  end

  class_methods do
    def delay(value) = @background_delay = value

    def timeout(value) = @execution_timeout = value

    def on_timeout(&handler) = @on_timeout = handler

    def background_delay = @background_delay ||= 1.second

    def execution_timeout = @execution_timeout ||= 5.minutes

    def timeout_handler = @on_timeout

    def with_timeout(data) = data.merge(_execution_timeout: execution_timeout.from_now.utc)

    def restart_zombie_tasks = zombies.find_each { |t| t.restart! }
  end

  def zombie? = Time.now > (updated_at + zombie_delay)

  private def background_delay = self.class.background_delay
  private def zombie_delay = background_delay * 3
  private def zombie_time = becomes_zombie_at || Time.now
  private def execution_timeout = self.class.execution_timeout
  private def timeout_handler = self.class.timeout_handler
  private def timeout!
    return unless timeout_expired?
    timeout_handler.nil? ? raise(Operations::Timeout.new("Timeout expired", self)) : timeout_handler.call
  end
  private def timeout_expired? = data[:_execution_timeout].present? && data[:_execution_timeout] < Time.now.utc
end
