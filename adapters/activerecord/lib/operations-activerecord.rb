# operations-activerecord
# ActiveRecord storage adapter for Operations V2

require "active_record"
require "operations/v2"

# Load the base adapter from core
require_relative "../../lib/operations/v2/adapters/storage/base"

# Load ActiveRecord-specific code
require_relative "operations/models/task_record"
require_relative "operations/adapters/storage/active_record"

module Operations
  module ActiveRecord
    class Error < StandardError; end
  end
end
