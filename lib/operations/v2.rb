# Operations V2 - Rails-free implementation with pluggable adapters
# Following YAGNI: Phase 1 has concrete implementations, no abstractions yet

require_relative "v2/errors"
require_relative "v2/handlers/action_handler"
require_relative "v2/handlers/decision_handler"
require_relative "v2/handlers/wait_handler"
require_relative "v2/handlers/result_handler"
require_relative "v2/handlers/interaction_handler"
require_relative "v2/memory_storage"
require_relative "v2/inline_executor"
require_relative "v2/dsl"
require_relative "v2/task"

module Operations
  module V2
    class << self
      attr_writer :storage, :executor

      # Simple configuration for Phase 1
      def storage
        @storage ||= MemoryStorage.new
      end

      def executor
        @executor ||= InlineExecutor.new
      end

      def configure
        yield self
      end
    end
  end
end
