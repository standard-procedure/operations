module Operations
  module V2
    module Adapters
      module Executor
        # Base interface for executor adapters
        # Learned from Phase 1 Inline implementation what methods are actually needed
        class Base
          # Execute a task synchronously, block until complete or sleeping
          # @param task [Operations::V2::Task] the task to execute
          # @return [Operations::V2::Task] the executed task
          def call(task)
            raise NotImplementedError, "#{self.class} must implement #call"
          end

          # Schedule task for background execution, return immediately
          # @param task [Operations::V2::Task] the task to schedule
          # @return [Operations::V2::Task] the task
          def later(task)
            raise NotImplementedError, "#{self.class} must implement #later"
          end

          # Resume a sleeping task
          # @param task [Operations::V2::Task] the task to wake
          # @return [Operations::V2::Task] the task
          def wake(task)
            raise NotImplementedError, "#{self.class} must implement #wake"
          end
        end
      end
    end
  end
end
