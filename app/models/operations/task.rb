module Operations
  class Task < ApplicationRecord
    include StateManagement
    include Deletion
    enum :status, in_progress: 0, completed: 1, failed: -1
    composed_of :results, class_name: "OpenStruct", constructor: ->(results) { results.to_h }, converter: ->(hash) { OpenStruct.new(hash) }
    serialize :results, coder: Operations::GlobalIDSerialiser, type: Hash, default: {}

    def self.call(data = {})
      raise MissingInputsError, "Missing inputs: #{missing_inputs_from(data).join(", ")}" unless required_inputs_are_present_in?(data)
      create!(state: initial_state).tap do |task|
        task.send(:process_current_state, DataCarrier.new(data.merge(task: task)))
      end
    end

    def go_to(state, data = {}, message = nil)
      update!(state: state, status_message: message || state.to_s)
      process_current_state(data)
    end

    def fail_with(message) = update! status: "failed", results: {failure_message: message.to_s}

    private def complete(results) = update!(status: "completed", results: results)
  end
end
