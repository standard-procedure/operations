class Operations::WakeTaskJob < ApplicationJob
  queue_as { arguments.first.class.queue_as }

  def perform(task) = task.wake_up!
end
