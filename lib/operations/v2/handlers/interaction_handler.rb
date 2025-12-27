module Operations
  module V2
    module Handlers
      class InteractionHandler
        def initialize(name, task_class, &implementation)
          @name = name.to_sym
          @task_class = task_class
          @implementation = implementation
          @valid_states = []

          # Capture name in local variable for closure
          interaction_name = name.to_s

          # Define the interaction method on the task class
          task_class.define_method(name) do |*args|
            handler = self.class.interaction_handler_for(interaction_name)
            handler.call(self, *args)
          end
        end

        def when(*states)
          @valid_states = states.map(&:to_s)
          self
        end

        def immediate?
          true
        end

        def call(task, *args)
          unless @valid_states.empty? || @valid_states.include?(task.current_state)
            raise Operations::V2::InvalidState,
              "Cannot call #{@name} when in state #{task.current_state}"
          end

          task.instance_exec(*args, &@implementation)

          if task.waiting?
            task.wake_up!
          end
        end
      end
    end
  end
end
