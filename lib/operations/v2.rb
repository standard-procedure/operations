# Operations V2 - Rails-free implementation with pluggable adapters
# Phase 2: Adapter pattern with Base interfaces extracted from Phase 1 implementations

require_relative "v2/errors"
require_relative "v2/handlers/action_handler"
require_relative "v2/handlers/decision_handler"
require_relative "v2/handlers/wait_handler"
require_relative "v2/handlers/result_handler"
require_relative "v2/handlers/interaction_handler"
require_relative "v2/adapters/storage/base"
require_relative "v2/adapters/storage/memory"
require_relative "v2/adapters/executor/base"
require_relative "v2/adapters/executor/inline"
require_relative "v2/dsl"
require_relative "v2/task"

# Backward compatibility - old paths still work
module Operations
  module V2
    MemoryStorage = Adapters::Storage::Memory
    InlineExecutor = Adapters::Executor::Inline
  end
end

module Operations
  module V2
    class << self
      attr_writer :storage, :executor

      # Configuration block for setting adapters
      #
      # @example Basic configuration
      #   Operations::V2.configure do |config|
      #     config.storage = Operations::V2::Adapters::Storage::Memory.new
      #     config.executor = Operations::V2::Adapters::Executor::Inline.new
      #   end
      #
      # @example Rails configuration with ActiveRecord
      #   require 'operations-activerecord'
      #   Operations::V2.configure do |config|
      #     config.storage = Operations::V2::Adapters::Storage::ActiveRecord.new
      #     config.executor = Operations::V2::Adapters::Executor::Inline.new
      #   end
      #
      def configure
        yield self
      end

      # Get current storage adapter (defaults to Memory)
      # @return [Operations::V2::Adapters::Storage::Base]
      def storage
        @storage ||= Adapters::Storage::Memory.new
      end

      # Get current executor adapter (defaults to Inline)
      # @return [Operations::V2::Adapters::Executor::Base]
      def executor
        @executor ||= Adapters::Executor::Inline.new
      end
    end
  end
end
