module Operations
  class AgentTimeoutJob < ApplicationJob
    queue_as Rails.application.config.operations_agent_timeout_queue || :default

    def perform agent
      agent.timeout!
    end
  end
end
