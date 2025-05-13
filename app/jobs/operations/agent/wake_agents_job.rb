class Operations::Agent::WakeAgentsJob < ApplicationJob
  queue_as :default

  def perform = Operations::Agent.waiting.ready_to_wake.find_each { |agent| Operations::Agent::RunnerJob.perform_later(agent) }
end
