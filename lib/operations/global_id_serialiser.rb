module Operations
  # Serialise and deserialise data to and from JSON
  # Unlike the standard JSON coder, this coder uses the ActiveJob::Arguments serializer.
  # This means that if the data contains an ActiveRecord model, it will be serialised as a GlobalID string
  #
  # Usage:
  # class MyModel < ApplicationRecord
  #   serialize :data, coder: GlobalIDSerialiser, type: Hash, default: {}
  # end
  # @my_model = MyModel.create! data: {hello: "world", user: User.first}
  # puts @my_model[:data] # => {hello: "world", user: #<User id: 1>}
  class GlobalIDSerialiser
    def self.dump(data) = ActiveSupport::JSON.dump(ActiveJob::Arguments.serialize([data]))

    def self.load(json) = ActiveJob::Arguments.deserialize(ActiveSupport::JSON.decode(json)).first
  end
end
