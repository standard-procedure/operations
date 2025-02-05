module Operations::Task::Background
  extend ActiveSupport::Concern

  class_methods do
    def delay(value)
      @background_delay = value
    end

    def timeout(value)
      @execution_timeout = value
    end

    def background_delay = @background_delay ||= 1.second

    def execution_timeout = @execution_timeout ||= 5.minutes

    def with_timeout(data) = data.merge(_execution_timeout: execution_timeout.from_now.utc)
  end

  private def background_delay = self.class.background_delay
  private def execution_timeout = self.class.execution_timeout
  private def timeout!
    raise Operations::Timeout.new("Timeout expired", self) if timeout_expired?
  end
  private def timeout_expired? = data[:_execution_timeout].present? && data[:_execution_timeout] < Time.now.utc
end
