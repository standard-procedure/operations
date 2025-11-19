class User < ApplicationRecord
  include Operations::Participant

  validates :name, presence: true
  def can?(action, target) = has_permission?
end
