# TODO: Move this into its own gem as I'm already using elsewhere
module Operations::HasDataAttributes
  extend ActiveSupport::Concern

  class_methods do
    def data_attribute_in field_name, name, cast_type = :string, **options
      name = name.to_sym
      typecaster = cast_type.nil? ? nil : ActiveRecord::Type.lookup(cast_type)
      typecast_value = ->(value) { typecaster.nil? ? value : typecaster.cast(value) }
      define_attribute_method name
      if cast_type != :boolean
        define_method(name) { typecast_value.call(send(field_name.to_sym)[name]) || options[:default] }
      else
        define_method(name) do
          value = typecast_value.call(send(field_name.to_sym)[name])
          [true, false].include?(value) ? value : options[:default]
        end
        alias_method :"#{name}?", name
      end
      define_method(:"#{name}=") do |value|
        attribute_will_change! name
        send(field_name.to_sym)[name] = typecast_value.call(value)
      end
    end

    def model_attribute_in field_name, name, class_name = nil, **options
      id_attribute_name = :"#{name}_global_id"
      data_attribute_in field_name, id_attribute_name, :string, **options

      define_method(name.to_sym) do
        id = send id_attribute_name.to_sym
        id.nil? ? nil : GlobalID::Locator.locate(id)
      rescue ActiveRecord::RecordNotFound
        nil
      end

      define_method(:"#{name}=") do |model|
        raise ArgumentError.new("#{model} is not #{class_name} - #{name}") if class_name.present? && model.present? && !model.is_a?(class_name.constantize)
        id = model.nil? ? nil : model.to_global_id.to_s
        send :"#{id_attribute_name}=", id
      end
    end

    def data_attributes(*attributes) = attributes.each { |attribute| data_attribute(attribute) }

    def data_attribute(name, cast_type = nil, **options) = data_attribute_in :data, name, cast_type, **options

    def data_model(name, class_name = nil, **options) = model_attribute_in :data, name, class_name, **options
  end
end
