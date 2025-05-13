class Operations::Agent::RunnerJob < ApplicationJob
  queue_as :default

  def perform(agent) = agent.perform!
end
