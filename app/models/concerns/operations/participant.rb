module Operations
  module Participant
    extend ActiveSupport::Concern

    included do
      has_many :operations_participants, class_name: "Operations::TaskParticipant", as: :participant, dependent: :destroy
      has_many :operations, class_name: "Operations::Task", through: :operations_participants, source: :task
    end

    def operations_as(attribute_name) = operations.joins(:participants).where(participants: {attribute_name: attribute_name, participant: self})
  end
end
