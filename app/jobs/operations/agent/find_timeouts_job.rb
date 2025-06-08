class Operations::Agent::FindTimeoutsJob < ApplicationJob
  queue_as :default

  def perform = Operations::Agent.active.timed_out.find_each { |agent| Operations::Agent::TimeoutJob.perform_later(agent) }
end
