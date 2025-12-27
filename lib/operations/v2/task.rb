module Operations
  module V2
    class Task
      include DSL

      attr_accessor :id, :type, :status, :current_state
      attr_accessor :attributes, :models
      attr_accessor :parent_task_id
      attr_accessor :exception_class, :exception_message, :exception_backtrace
      attr_accessor :created_at, :updated_at, :wake_at, :timeout_at, :delete_at

      def initialize(**attrs)
        # Extract system attributes
        @id = attrs.delete(:id)
        @type = self.class.name
        @status = attrs.delete(:status) || :active
        @current_state = attrs.delete(:current_state) || self.class.initial_state
        @parent_task_id = attrs.delete(:parent_task_id)
        @created_at = attrs.delete(:created_at) || Time.now.utc
        @updated_at = attrs.delete(:updated_at) || Time.now.utc
        @wake_at = attrs.delete(:wake_at)
        @timeout_at = attrs.delete(:timeout_at) || (Time.now.utc + self.class.execution_timeout)
        @delete_at = attrs.delete(:delete_at) || (Time.now.utc + self.class.deletion_time)

        # Handle pre-serialized data or new instances
        @attributes = attrs.delete(:attributes) || {}
        @models = attrs.delete(:models) || {}

        # Extract defined attributes and models from remaining kwargs
        self.class.attribute_definitions.each_key do |attr_name|
          if attrs.key?(attr_name)
            @attributes[attr_name.to_s] = attrs.delete(attr_name)
          end
        end

        self.class.model_definitions.each_key do |model_name|
          if attrs.key?(model_name)
            @models[model_name.to_s] = attrs.delete(model_name)
          end
        end

        self.class.models_definitions.each_key do |models_name|
          if attrs.key?(models_name)
            @models[models_name.to_s] = attrs.delete(models_name)
          end
        end

        initialize_attributes
        validate!
      end

      # Serialization for storage
      def to_h
        {
          id: @id,
          type: @type,
          status: @status.to_s,
          current_state: @current_state,
          attributes: @attributes,
          models: serialize_models,
          parent_task_id: @parent_task_id,
          exception_class: @exception_class,
          exception_message: @exception_message,
          exception_backtrace: @exception_backtrace,
          created_at: @created_at,
          updated_at: @updated_at,
          wake_at: @wake_at,
          timeout_at: @timeout_at,
          delete_at: @delete_at
        }
      end

      # Deserialization from storage
      def self.restore_from(data)
        task = allocate
        task.id = data[:id]
        task.type = data[:type]
        task.status = data[:status].to_sym
        task.current_state = data[:current_state]
        task.attributes = data[:attributes] || {}
        task.models = task.deserialize_models(data[:models] || {})
        task.parent_task_id = data[:parent_task_id]
        task.exception_class = data[:exception_class]
        task.exception_message = data[:exception_message]
        task.exception_backtrace = data[:exception_backtrace]
        task.created_at = data[:created_at]
        task.updated_at = data[:updated_at]
        task.wake_at = data[:wake_at]
        task.timeout_at = data[:timeout_at]
        task.delete_at = data[:delete_at]
        task
      end

      # Execution methods
      def self.call(**attributes)
        task = new(**attributes)
        Operations::V2.executor.call(task)
        Operations::V2.storage.save(task)
        task
      end

      def self.perform_now(**attributes)
        call(**attributes)
      end

      def self.later(**attributes)
        task = new(**attributes.merge(status: :waiting))
        Operations::V2.storage.save(task)
        Operations::V2.executor.later(task)
        task
      end

      def self.perform_later(**attributes)
        later(**attributes)
      end

      def self.find(id)
        Operations::V2.storage.find(id)
      end

      def execute_state_machine
        previous_state = ""

        while active? && (previous_state != current_state)
          previous_state = current_state
          handler = self.class.handler_for(current_state)

          raise InvalidState, "No handler for state: #{current_state}" unless handler

          handler.call(self)
          Operations::V2.storage.save(self)
        end
      rescue => ex
        record_error!(ex)
        raise
      end

      def go_to(next_state)
        self.current_state = next_state.to_s
        handler = self.class.handler_for(next_state)
        self.status = handler.immediate? ? :active : :waiting

        if waiting?
          self.wake_at = Time.now.utc + self.class.background_delay
        end
      end

      def sleep_until_woken
        self.status = :waiting
        self.wake_at = Time.now.utc + self.class.background_delay
      end

      def wake_up!
        return call_timeout_handler if timeout_expired?
        Operations::V2.executor.wake(self)
        Operations::V2.storage.save(self)
      end

      def complete
        self.status = :completed
      end

      # Status predicates
      def active?
        status == :active
      end

      def waiting?
        status == :waiting
      end

      def completed?
        status == :completed
      end

      def failed?
        status == :failed
      end

      # Alias for compatibility
      def in?(state)
        current_state == state.to_s
      end

      alias_method :waiting_until?, :in?

      # Sub-task methods
      def start(task_class, **attributes)
        task_class.later(**attributes.merge(parent_task_id: id))
      end

      def sub_tasks
        Operations::V2.storage.sub_tasks_of(self)
      end

      def active_sub_tasks
        sub_tasks.select(&:active?)
      end

      def completed_sub_tasks
        sub_tasks.select(&:completed?)
      end

      def failed_sub_tasks
        sub_tasks.select(&:failed?)
      end

      # Testing support
      def self.test(state, **attributes)
        task = new(**attributes.merge(current_state: state))
        handler = handler_for(state)
        handler.call(task)
        task
      end

      def deserialize_models(serialized_models)
        serialized_models.transform_values do |value|
          if value.is_a?(Array)
            value.map { |v| Operations::V2.storage.deserialise_model(v, v[:type]) }
          else
            Operations::V2.storage.deserialise_model(value, value[:type])
          end
        end
      end

      private

      def record_error!(exception)
        self.status = :failed
        self.exception_class = exception.class.to_s
        self.exception_message = exception.message
        self.exception_backtrace = exception.backtrace&.join("\n")
        Operations::V2.storage.save(self)
      end

      def timeout_expired?
        timeout_at && timeout_at < Time.now.utc
      end

      def call_timeout_handler
        handler = self.class.timeout_handler
        if handler
          instance_exec(&handler)
        else
          raise Operations::V2::Timeout.new("Timeout expired", self)
        end
      end

      def serialize_models
        models.transform_values do |value|
          if value.is_a?(Array)
            value.map { |v| Operations::V2.storage.serialise_model(v) }
          else
            Operations::V2.storage.serialise_model(value)
          end
        end
      end
    end
  end
end
