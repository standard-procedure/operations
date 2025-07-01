require "ostruct"
require "has_attributes"

module Operations
  class Error < StandardError
    def initialize message, task = nil
      super(message)
      @task = task
    end
    attr_reader :task
  end
  require "operations/version"
  require "operations/engine"
  require "operations/failure"
  require "operations/timeout"
  require "operations/no_decision"
  require "operations/invalid_state"
end
