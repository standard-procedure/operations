module Operations
  class TaskRunnerJob < ApplicationJob
    queue_as :default

    def perform(task, data: {})
      task.perform(data) if task.waiting?
    rescue => ex
      Rails.logger.error "TaskRunnerJob failed: #{ex.message} for #{task.inspect}"
    end
  end
end
