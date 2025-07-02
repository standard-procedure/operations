class Document < ApplicationRecord
  include Operations::Participant
  validates :filename, presence: true
end
