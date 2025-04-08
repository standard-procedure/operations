module Operations
  class AgentRunnerJob < ApplicationJob
    queue_as :default

    def perform agent
      agent.perform if agent.waiting?
    end
  end
end
