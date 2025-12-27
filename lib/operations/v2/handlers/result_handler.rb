module Operations
  module V2
    module Handlers
      class ResultHandler
        def initialize(name)
          @name = name.to_sym
        end

        def immediate?
          true
        end

        def call(task)
          task.complete
        end
      end
    end
  end
end
