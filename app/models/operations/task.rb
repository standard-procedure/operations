module Operations
  class Task < ApplicationRecord
    include StateManagement
    include Attributes
    include Deletion
    enum :status, active: 0, completed: 1, failed: -1
  end
end
