class Operations::Agent::TimeoutJob < ApplicationJob
  queue_as :default

  def perform(agent) = agent.timeout!
end
