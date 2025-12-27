require_relative "base"

module Operations
  module V2
    module Adapters
      module Executor
        # Inline executor adapter (synchronous)
        # Everything runs in current thread - perfect for testing
        class Inline < Base
          def call(task)
            task.execute_state_machine
            task
          end

          def later(task)
            # In inline mode, just execute immediately
            call(task)
          end

          def wake(task)
            task.status = :active
            call(task)
          end
        end
      end
    end
  end
end
