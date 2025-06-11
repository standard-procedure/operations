class Operations::Agent::WakeAgentsJob < ApplicationJob
  queue_as :default

  def perform
    # Cannot use `Operations::Agent` here because sometimes Rails STI does not pick up the subclasses
    # - not sure why, somthing to do with eager-loading
    Operations::Task.waiting.ready_to_wake.find_each do |task|
      Operations::Agent::RunnerJob.perform_later(task)
    end
  end
end
