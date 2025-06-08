module Operations
  class Agent::Runner
    def initialize
      Rails.application.eager_load! # Ensure all sub-classes are loaded in dev mode
      @stopped = false
    end

    def start
      puts "Starting #{self.class.name}"
      register_signal_handlers
      puts "...signal handlers registered"
      until @stopped
        process_timed_out_agents
        process_waiting_agents
        sleep 1
      end
      puts "...stopping"
    end

    def stop
      @stopped = true
    end

    def self.start = new.start

    private def process_timed_out_agents = Agent::FindTimeoutsJob.perform_later

    private def process_waiting_agents = Agent::WakeAgentsJob.perform_later

    private def register_signal_handlers
      %w[INT TERM].each do |signal|
        trap(signal) { @stopped = true }
      end

      trap(:QUIT) { exit! }
    end
  end
end
