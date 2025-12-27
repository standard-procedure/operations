module Operations
  module V2
    class Error < StandardError
      def initialize(message, task = nil)
        super(message)
        @task = task
      end
      attr_reader :task
    end

    class Failure < Error; end
    class Timeout < Error; end
    class NoDecision < Error; end
    class InvalidState < Error; end
    class ValidationError < Error; end
  end
end
