require "ostruct"

module Operations
  class Error < StandardError
  end
  require "operations/version"
  require "operations/engine"
  require "operations/global_id_serialiser"
  require "operations/missing_inputs_error"
end
