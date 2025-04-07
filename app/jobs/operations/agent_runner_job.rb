module Operations
  class AgentRunnerJob < ApplicationJob
    queue_as Rails.application.config.operations_agent_runner_queue || :default

    def perform agent
      agent.perform if agent.waiting?
    end
  end
end
