module Operations
  class AgentTimeoutJob < ApplicationJob
    queue_as :default

    def perform agent
      agent.timeout!
    end
  end
end
