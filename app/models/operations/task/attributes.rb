module Operations::Task::Attributes
  extend ActiveSupport::Concern

  included do
    serialize :data, coder: Operations::GlobalIDSerialiser, type: Hash, default: {}
    data :results, default: {}
  end

  class_methods do
    # Define an attribute on this model, which is serialised to and from the data field
    def data(name, cast_type = :string, **options)
      attribute name, cast_type, **options
      define_method(name) do
        data[name.to_s] || options[:default]
      end
      define_method(:"#{name}=") do |value|
        data[name.to_s] = value
      end
      if cast_type == :boolean
        define_method(:"#{name}?") do
          data[name.to_s] == true
        end
      end
      define_method(:"#{name}_changed?") do
        data_changed? && data_was[name.to_s] != data[name.to_s]
      end
      define_method(:"#{name}_was") do
        data_was[name.to_s]
      end
    end
  end
end
