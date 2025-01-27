module Operations
  class Task < ApplicationRecord
    enum :status, active: 0, completed: 1, failed: -1
    attribute :state, :string
    validate :state_is_valid
    serialize :data, coder: GlobalIDSerialiser, type: Hash, default: {}
    validates :delete_at, presence: true
  end
end
