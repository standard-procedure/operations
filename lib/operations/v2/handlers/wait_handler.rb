module Operations
  module V2
    module Handlers
      class WaitHandler < DecisionHandler
        def immediate?
          false
        end

        def call(task)
          # Try to evaluate conditions
          begin
            super
          rescue Operations::V2::NoDecision
            # If no conditions match, task sleeps
            task.sleep_until_woken
          end
        end
      end
    end
  end
end
