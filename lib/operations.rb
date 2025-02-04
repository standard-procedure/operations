require "ostruct"

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
  require "operations/global_id_serialiser"
  require "operations/failure"
end
