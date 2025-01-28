class User < ApplicationRecord
  validates :name, presence: true
  def can?(action, target) = has_permission?
end
