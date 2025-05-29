require "ostruct"
require "global_id_serialiser"

module Operations
  class Error < StandardError
    def initialize message, task = nil
      super(message)
      @task = task
    end
    attr_reader :task
  end
  require "operations/has_data_attributes"
  require "operations/version"
  require "operations/engine"
  require "operations/failure"
  require "operations/timeout"
  require "operations/no_decision"
  require "operations/invalid_state"
  require "operations/exporters/svg"
end
