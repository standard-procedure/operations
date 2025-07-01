class Operations::WakeTaskJob < ApplicationJob
  queue_as :default

  def perform(task) = task.wake_up!
end
