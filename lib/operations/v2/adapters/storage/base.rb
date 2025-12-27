module Operations
  module V2
    module Adapters
      module Storage
        # Base interface for storage adapters
        # Learned from Phase 1 Memory implementation what methods are actually needed
        class Base
          # Persist a task, assign ID if new
          # @param task [Operations::V2::Task] the task to save
          # @return [Operations::V2::Task] the saved task with ID assigned
          def save(task)
            raise NotImplementedError, "#{self.class} must implement #save"
          end

          # Retrieve a task by ID
          # @param id [String] the task ID
          # @return [Operations::V2::Task, nil] the task or nil if not found
          def find(id)
            raise NotImplementedError, "#{self.class} must implement #find"
          end

          # Find tasks ready to wake (wake_at <= current time)
          # @param task_class [Class, nil] optional filter by task class
          # @return [Array<Operations::V2::Task>] tasks ready to wake
          def sleeping_tasks(task_class = nil)
            raise NotImplementedError, "#{self.class} must implement #sleeping_tasks"
          end

          # Find child tasks of a parent task
          # @param task [Operations::V2::Task] the parent task
          # @return [Array<Operations::V2::Task>] child tasks
          def sub_tasks_of(task)
            raise NotImplementedError, "#{self.class} must implement #sub_tasks_of"
          end

          # Delete old tasks
          # @param task_class [Class, nil] optional filter by task class
          # @param before [Time] delete tasks with delete_at before this time
          # @return [Integer] number of tasks deleted
          def delete_old(task_class = nil, before:)
            raise NotImplementedError, "#{self.class} must implement #delete_old"
          end

          # Convert a model reference for storage
          # Default implementation works for objects with #id and #class
          # @param model [Object] the model to serialize
          # @return [Hash] serialized model reference {id:, type:}
          def serialise_model(model)
            {id: model.id, type: model.class.name}
          end

          # Restore a model reference from storage
          # Default implementation uses const_get and #find
          # @param data [Hash] serialized model data {id:, type:}
          # @param class_name [String] the model class name
          # @return [Object] the model instance
          def deserialise_model(data, class_name)
            Object.const_get(class_name).find(data[:id])
          end
        end
      end
    end
  end
end
