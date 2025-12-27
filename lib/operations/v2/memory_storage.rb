require "securerandom"

module Operations
  module V2
    # Concrete Memory storage implementation (no abstraction - YAGNI)
    # Thread-safe Hash-based storage for testing and simple single-process apps
    class MemoryStorage
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

      def serialise_model(model)
        {id: model.id, type: model.class.name}
      end

      def deserialise_model(data, class_name)
        Object.const_get(class_name).find(data[:id])
      end

      private

      def restore_task(data)
        task_class = Object.const_get(data[:type])
        task_class.restore_from(data)
      end
    end
  end
end
