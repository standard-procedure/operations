class Operations::Agent::FindTimeoutsJob < ApplicationJob
  queue_as :default

  def perform = Operations::Agent.active.timed_out.find_each { |agent| Operations::AgentTimeoutJob.perform_later(agent) }
end
