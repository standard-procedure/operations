module Operations
  module V2
    module Handlers
      class ActionHandler
        attr_accessor :next_state

        def initialize(name, &action)
          @name = name.to_sym
          @action = action
          @next_state = nil
        end

        def then(next_state)
          @next_state = next_state
          self
        end

        def immediate?
          true
        end

        def call(task)
          task.instance_exec(&@action)
          task.go_to(@next_state) if @next_state
        end
      end
    end
  end
end
