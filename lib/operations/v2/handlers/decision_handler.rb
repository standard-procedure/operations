module Operations
  module V2
    module Handlers
      class DecisionHandler
        def initialize(name, &config)
          @name = name.to_sym
          @conditions = []
          @destinations = []
          @true_state = nil
          @false_state = nil
          instance_eval(&config) if block_given?
        end

        def immediate?
          true
        end

        def condition(&block)
          @conditions << block
        end

        def go_to(destination)
          @destinations << destination
        end

        def if_true(state)
          @true_state = state
        end

        def if_false(state)
          @false_state = state
        end

        def call(task)
          if has_true_false_handlers?
            handle_boolean_decision(task)
          else
            handle_multiple_conditions(task)
          end
        end

        private

        def has_true_false_handlers?
          !@true_state.nil? || !@false_state.nil?
        end

        def handle_boolean_decision(task)
          result = task.instance_eval(&@conditions.first)
          next_state = result ? @true_state : @false_state
          task.go_to(next_state)
        end

        def handle_multiple_conditions(task)
          condition = @conditions.find { |c| task.instance_eval(&c) }
          raise Operations::V2::NoDecision, "No conditions matched in #{@name}" unless condition

          index = @conditions.index(condition)
          task.go_to(@destinations[index])
        end
      end
    end
  end
end
