require "active_record"

module Operations
  module V2
    module Adapters
      module Storage
        # ActiveRecord storage adapter
        # Provides database persistence for Operations tasks in Rails apps
        class ActiveRecord < Base
          def initialize
            # Ensure TaskRecord model exists
            require_relative "../../models/task_record"
          end

          def save(task)
            record = find_or_initialize_record(task)

            # Convert task to hash and update record
            task_data = task.to_h
            record.assign_attributes(
              task_type: task_data[:type],
              status: task_data[:status],
              current_state: task_data[:current_state],
              data: {
                attributes: task_data[:attributes],
                models: task_data[:models]
              },
              parent_task_id: task_data[:parent_task_id],
              exception_class: task_data[:exception_class],
              exception_message: task_data[:exception_message],
              exception_backtrace: task_data[:exception_backtrace],
              wake_at: task_data[:wake_at],
              timeout_at: task_data[:timeout_at],
              delete_at: task_data[:delete_at]
            )

            record.save!
            task.id = record.id
            task.created_at = record.created_at
            task.updated_at = record.updated_at
            task
          end

          def find(id)
            record = Operations::TaskRecord.find_by(id: id)
            return nil unless record
            restore_task_from_record(record)
          end

          def sleeping_tasks(task_class = nil)
            scope = Operations::TaskRecord.where(status: "waiting")
              .where("wake_at <= ?", Time.now.utc)

            scope = scope.where(task_type: task_class.name) if task_class

            scope.map { |record| restore_task_from_record(record) }
          end

          def sub_tasks_of(task)
            Operations::TaskRecord.where(parent_task_id: task.id)
              .map { |record| restore_task_from_record(record) }
          end

          def delete_old(task_class = nil, before:)
            scope = Operations::TaskRecord.where("delete_at <= ?", before)
            scope = scope.where(task_type: task_class.name) if task_class
            scope.delete_all
          end

          private

          def find_or_initialize_record(task)
            if task.id
              Operations::TaskRecord.find_or_initialize_by(id: task.id)
            else
              Operations::TaskRecord.new
            end
          end

          def restore_task_from_record(record)
            task_class = Object.const_get(record.task_type)

            task_class.restore_from(
              id: record.id,
              type: record.task_type,
              status: record.status,
              current_state: record.current_state,
              attributes: record.data["attributes"] || {},
              models: record.data["models"] || {},
              parent_task_id: record.parent_task_id,
              exception_class: record.exception_class,
              exception_message: record.exception_message,
              exception_backtrace: record.exception_backtrace,
              created_at: record.created_at,
              updated_at: record.updated_at,
              wake_at: record.wake_at,
              timeout_at: record.timeout_at,
              delete_at: record.delete_at
            )
          end
        end
      end
    end
  end
end
