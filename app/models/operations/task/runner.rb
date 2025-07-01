module Operations
  class Task::Runner
    def initialize
      @stopped = false
    end

    def start
      puts "Starting #{self.class.name}"
      register_signal_handlers
      puts "...signal handlers registered"
      until @stopped
        Rails.application.eager_load! if Rails.env.development? # Ensure all sub-classes are loaded in dev mode
        Task.wake_sleeping
        Task.delete_old
        sleep 30
      end
      puts "...stopping"
    end

    def stop
      @stopped = true
    end

    def self.start = new.start

    private def register_signal_handlers
      %w[INT TERM].each do |signal|
        trap(signal) { @stopped = true }
      end

      trap(:QUIT) { exit! }
    end
  end
end
