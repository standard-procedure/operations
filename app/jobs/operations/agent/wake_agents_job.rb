class Operations::Agent::WakeAgentsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info { Operations::Task.waiting.pluck(:type, :state).map { |info| info.join(": ") }.join(", ") }
    Operations::Agent.waiting.ready_to_wake.find_each do |agent|
      Operations::Agent::RunnerJob.perform_later(agent)
    end
  end
end
