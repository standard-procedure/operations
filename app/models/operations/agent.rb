module Operations
  class Agent < Task
    include Plan
    scope :ready_to_wake, -> { ready_to_wake_at(Time.now) }
    scope :ready_to_wake_at, ->(time) { where(wakes_at: ..time) }
    scope :timed_out, -> { timed_out_at(Time.now) }
    scope :timed_out_at, ->(time) { where(times_out_at: ..time) }

    def go_to(state, data = {}, message: nil)
      record_state_transition! state: state, data: data.to_h, status_message: (message || state).to_s.truncate(240)
      handler_for(state).immediate? ? perform : wait
    end

    protected def record_state_transition! **params
      params[:wakes_at] = Time.now.utc + background_delay
      params[:times_out_at] ||= Time.now.utc + execution_timeout
      super
    end

    private def wait
      waiting!
    rescue => ex
      update! status: "failed", status_message: ex.message.to_s.truncate(240), results: {failure_message: ex.message, exception_class: ex.class.name, exception_backtrace: ex.backtrace}
      raise ex
    end
  end
end
