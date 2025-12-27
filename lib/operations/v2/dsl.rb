module Operations
  module V2
    module DSL
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def starts_with(value)
          @initial_state = value.to_s
        end

        def action(name, &handler)
          state_handlers[name.to_s] = Handlers::ActionHandler.new(name, &handler)
        end

        def decision(name, &config)
          state_handlers[name.to_s] = Handlers::DecisionHandler.new(name, &config)
        end

        def wait_until(name, &config)
          state_handlers[name.to_s] = Handlers::WaitHandler.new(name, &config)
        end

        def interaction(name, &implementation)
          interaction_handlers[name.to_s] = Handlers::InteractionHandler.new(name, self, &implementation)
        end

        def result(name)
          state_handlers[name.to_s] = Handlers::ResultHandler.new(name)
        end

        def go_to(state)
          last_action = state_handlers.values.reverse.find { |h| h.is_a?(Handlers::ActionHandler) }
          raise ArgumentError, "No action handler defined yet" unless last_action
          last_action.next_state = state.to_sym
        end

        def initial_state
          @initial_state || "start"
        end

        def delay(value)
          @background_delay = value
        end

        def timeout(value)
          @execution_timeout = value
        end

        def delete_after(value)
          @deletion_time = value
        end

        def on_timeout(&handler)
          @on_timeout = handler
        end

        def background_delay
          @background_delay ||= 60 # 1 minute in seconds
        end

        def execution_timeout
          @execution_timeout ||= 86400 # 24 hours in seconds
        end

        def deletion_time
          @deletion_time ||= 7776000 # 90 days in seconds
        end

        def timeout_handler
          @on_timeout
        end

        def state_handlers
          @state_handlers ||= {}
        end

        def handler_for(state)
          state_handlers[state.to_s]
        end

        def interaction_handlers
          @interaction_handlers ||= {}
        end

        def interaction_handler_for(name)
          interaction_handlers[name.to_s]
        end

        # Attribute DSL
        def has_attribute(name, type = :string, **options)
          attribute_definitions[name] = {type: type, options: options}

          define_method(name) do
            @attributes[name.to_s] || options[:default]
          end

          define_method("#{name}=") do |value|
            @attributes[name.to_s] = value
          end
        end

        def has_model(name, class_name = nil)
          model_definitions[name] = class_name || name.to_s.capitalize

          define_method(name) do
            @models[name.to_s]
          end

          define_method("#{name}=") do |value|
            @models[name.to_s] = value
          end
        end

        def has_models(name, class_name = nil)
          models_definitions[name] = class_name || name.to_s.sub(/s$/, "").capitalize

          define_method(name) do
            @models[name.to_s] || []
          end

          define_method("#{name}=") do |values|
            @models[name.to_s] = Array(values)
          end
        end

        def validates(attr, validations)
          validation_rules[attr] = validations
        end

        def attribute_definitions
          @attribute_definitions ||= {}
        end

        def model_definitions
          @model_definitions ||= {}
        end

        def models_definitions
          @models_definitions ||= {}
        end

        def validation_rules
          @validation_rules ||= {}
        end

        def index(*attrs)
          # V2: Index is not implemented yet - will be added when needed
          @indexed_attributes ||= []
          @indexed_attributes.concat(attrs.map(&:to_s))
        end
      end

      def validate!
        self.class.validation_rules.each do |attr, rules|
          value = send(attr)

          if rules[:presence] && (value.nil? || value == "")
            raise Operations::V2::ValidationError, "#{attr} is required"
          end
        end
      end

      def initialize_attributes
        # Set default values for attributes
        self.class.attribute_definitions.each do |name, definition|
          if @attributes[name.to_s].nil? && definition[:options][:default]
            @attributes[name.to_s] = definition[:options][:default]
          end
        end
      end
    end
  end
end
