module Operations
  class Agent::Runner
    def initialize
      @stopped = false
    end

    def start
      puts "Starting #{self.class.name}"
      register_signal_handlers
      puts "...signal handlers registered"
      until @stopped
        process_timed_out_agents
        process_waiting_agents
        sleep
      end
      puts "...stopping"
    end

    def stop
      @stopped = true
    end

    def self.start
      new.start
    end

    private def process_timed_out_agents
      Operations::Agent.active.timed_out.find_each do |agent|
        Operations::AgentTimeoutJob.perform_later(agent)
      end
    end

    private def process_waiting_agents
      Operations::Agent.waiting.ready_to_wake.find_each do |agent|
        Operations::AgentRunnerJob.perform_later(agent)
      end
    end

    private def register_signal_handlers
      %w[INT TERM].each do |signal|
        trap(signal) do
          @stopped = true
        end
      end

      trap(:QUIT) do
        exit!
      end
    end
  end
end
