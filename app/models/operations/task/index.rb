module Operations::Task::Index
  extend ActiveSupport::Concern

  class_methods do
    def index(*names) = @indexed_attributes = (@indexed_attributes || []) + names.map(&:to_sym)

    def indexed_attributes = @indexed_attributes ||= []
  end

  included do
    has_many :participants, class_name: "Operations::TaskParticipant", dependent: :destroy
    # validate :indexed_attributes_are_legal, if: -> { indexed_attributes.any? }
    after_save :store_participants, if: -> { indexed_attributes.any? }
  end

  private def indexed_attributes = self.class.indexed_attributes
  private def store_participants
    indexed_attributes.each do |attribute|
      models = Array.wrap(send(attribute))
      models.each do |model|
        participants.where(participant: model, attribute_name: attribute).first_or_create!
      end
    end
  end
end
