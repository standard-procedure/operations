module Operations::Task::Deletion
  extend ActiveSupport::Concern

  included do
    scope :for_deletion, -> { where(delete_at: ..Time.now.utc) }
    attribute :delete_at, :datetime, default: -> { deletes_after.from_now.utc }
    validates :delete_at, presence: true
  end

  class_methods do
    def delete_after(value) = @@deletes_after = value

    def deletes_after = @@deletes_after ||= 90.days

    def delete_expired = for_deletion.destroy_all
  end
end
