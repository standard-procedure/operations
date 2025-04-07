module Operations
  class Agent < Task
    include Background
    enum :status, in_progress: 0, waiting: 10, completed: 100, failed: -1

    def start sub_task_class, **data, &result_handler
      sub_task_class.start(**data)
    end

    def perform_later
      update! status: "waiting", wakes_at: Time.now + background_delay
      TaskRunnerJob.set(wait_until: background_delay.from_now).perform_later self
    end
    alias_method :restart!, :perform_later

    def self.start(**data)
      build(**with_timeout(data)).tap do |task|
        task.perform_later
      end
    end

    def go_to(state, data = {}, message: nil)
      update!(state: state, data: data.to_h, status_message: (message || state).to_s.truncate(240))
      perform_later
    end

    def self.build(**data)
      validate_inputs! data
      create!(state: initial_state, status: "waiting", data: data, status_message: "")
    end
  end
end
