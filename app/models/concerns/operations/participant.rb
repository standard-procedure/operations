module Operations
  module Participant
    extend ActiveSupport::Concern

    included do
      has_many :operations_task_participants, -> { includes(:task).order "created_at desc" }, class_name: "Operations::TaskParticipant", as: :participant, dependent: :destroy
      has_many :operations_tasks, class_name: "Operations::Task", through: :operations_task_participants, source: :task

      scope :involved_in_operation_as, ->(role:, context: "data") do
        joins(:operations_task_participants).tap do |scope|
          scope.where(operations_task_participants: {role: role}) if role
          scope.where(operations_task_participants: {context: context}) if context
        end
      end
    end
  end
end
