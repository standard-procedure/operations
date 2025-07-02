module Operations::Task::Index
  extend ActiveSupport::Concern

  class_methods do
    def index(*names) = @indexed_attributes = (@indexed_attributes || []) + names.map(&:to_sym)

    def indexed_attributes = @indexed_attributes ||= []
  end

  included do
    has_many :participants, class_name: "Operations::TaskParticipant", dependent: :destroy
    after_save :update_index, if: -> { indexed_attributes.any? }
  end

  private def indexed_attributes = self.class.indexed_attributes
  private def update_index = indexed_attributes.collect { |attribute| update_index_for(attribute) }
  private def update_index_for(attribute)
    models = Array.wrap(send(attribute))
    participants.where(attribute_name: attribute).where.not(participant: models).delete_all
    models.collect { |model| participants.where(participant: model, attribute_name: attribute).first_or_create! }
  end
end
