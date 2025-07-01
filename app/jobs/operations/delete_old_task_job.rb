class Operations::DeleteOldTaskJob < ApplicationJob
  queue_as :default

  def perform(task) = task.destroy
end
