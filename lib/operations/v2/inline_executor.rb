module Operations
  module V2
    # Concrete Inline executor implementation (no abstraction - YAGNI)
    # Everything runs synchronously in current thread
    class InlineExecutor
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
