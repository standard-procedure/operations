module Operations
  class TaskRunnerJob < ApplicationJob
    queue_as :default

    def perform task
      task.perform if task.waiting?
    rescue => ex
      Rails.logger.error "TaskRunnerJob failed: #{ex.message} for #{task.inspect}"
    end
  end
end
