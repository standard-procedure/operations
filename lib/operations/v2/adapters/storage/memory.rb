require "securerandom"
require_relative "base"

module Operations
  module V2
    module Adapters
      module Storage
        # In-memory storage adapter (thread-safe)
        # Perfect for testing and simple single-process apps
        class Memory < Base
          def initialize
            @store = {}
            @mutex = Mutex.new
          end

          def save(task)
            @mutex.synchronize do
              task.id ||= SecureRandom.uuid
              task.updated_at = Time.now.utc
              @store[task.id] = task.to_h
              task
            end
          end

          def find(id)
            @mutex.synchronize do
              data = @store[id]
              return nil unless data
              restore_task(data)
            end
          end

          def sleeping_tasks(task_class = nil)
            @mutex.synchronize do
              now = Time.now.utc
              @store.values
                .select { |data| data[:status] == "waiting" && data[:wake_at] && data[:wake_at] <= now }
                .select { |data| task_class.nil? || data[:type] == task_class.name }
                .map { |data| restore_task(data) }
            end
          end

          def sub_tasks_of(task)
            @mutex.synchronize do
              @store.values
                .select { |data| data[:parent_task_id] == task.id }
                .map { |data| restore_task(data) }
            end
          end

          def delete_old(task_class = nil, before:)
            @mutex.synchronize do
              to_delete = @store.values
                .select { |data| data[:delete_at] && data[:delete_at] <= before }
                .select { |data| task_class.nil? || data[:type] == task_class.name }

              to_delete.each { |data| @store.delete(data[:id]) }
              to_delete.count
            end
          end

          private

          def restore_task(data)
            task_class = Object.const_get(data[:type])
            task_class.restore_from(data)
          end
        end
      end
    end
  end
end
