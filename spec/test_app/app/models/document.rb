class Document < ApplicationRecord
  validates :filename, presence: true
end
