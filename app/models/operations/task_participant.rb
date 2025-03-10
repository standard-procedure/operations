module Operations
  class TaskParticipant < ApplicationRecord
    belongs_to :task
    belongs_to :participant, polymorphic: true

    validates :role, presence: true
    validates :context, presence: true
    validates :task_id, uniqueness: {scope: [:participant_type, :participant_id, :role, :context]}

    scope :in, ->(context) { where(context: context) }
  end
end
