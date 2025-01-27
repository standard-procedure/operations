module Operations
  class Task < ApplicationRecord
    include StateManagement
    include Attributes
    enum :status, active: 0, completed: 1, failed: -1
    attribute :state, :string
    # validate :state_is_valid
    serialize :data, coder: GlobalIDSerialiser, type: Hash, default: {}
    attribute :delete_at, :datetime, default: -> { 90.days.from_now }
    # validates :delete_at, presence: true
  end
end
