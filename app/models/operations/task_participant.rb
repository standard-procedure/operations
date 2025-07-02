module Operations
  class TaskParticipant < ApplicationRecord
    belongs_to :task
    belongs_to :participant, polymorphic: true

    validates :attribute_name, presence: true
    normalizes :attribute_name, with: ->(n) { n.to_s.strip }
  end
end
