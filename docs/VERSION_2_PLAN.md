# Operations V2 - Architecture Plan

## Executive Summary

This document outlines the plan for building Operations V2, a complete architectural refactoring that transforms the gem from a Rails Engine with tight ActiveRecord/ActiveJob coupling into a standalone Ruby gem with pluggable storage and executor adapters.

**Core Goals:**
- **Maintain the existing Task DSL** - No changes to user-facing API
- Remove all Rails dependencies from the core gem
- Implement pluggable storage adapters (in-memory default)
- Implement pluggable executor adapters (inline default)
- External adapters can be separate gems (ActiveRecord, ActiveJob, Async, etc.)

**Naming Convention:**
- Gem name: `standard_procedure_operations` (following standard_procedure_* pattern)
- Namespace: `Operations::` (classes like `Operations::Task`, `Operations::Storage::Memory`)
- Adapter gems: `operations-activerecord`, `operations-activejob`, `operations-async` (no standard_procedure prefix for optional adapters)

## Current Architecture (V1)

### Dependencies
- Rails >= 7.1.3 (hard dependency)
- standard_procedure_has_attributes
- ActiveRecord for persistence
- ActiveJob for background execution
- ActiveSupport::Concern for module composition

### Core Components
1. **Operations::Task** - inherits from ApplicationRecord
2. **Operations::Task::Plan** - DSL module using ActiveSupport::Concern
3. **Handler Classes** - ActionHandler, DecisionHandler, WaitHandler, ResultHandler, InteractionHandler
4. **Operations::Engine** - Rails::Engine integration
5. **Background Jobs** - WakeTaskJob, DeleteOldTaskJob

### Current DSL Features
```ruby
class MyTask < Operations::Task
  # Attribute definitions (via HasAttributes)
  has_attribute :name, :string
  has_model :user, "User"
  has_models :documents, "Document"

  # Task configuration
  starts_with :initial_state
  delay 1.minute
  timeout 24.hours
  queue :default
  runs_on :sidekiq
  delete_after 90.days
  on_timeout { handle_timeout }

  # State handlers
  action :do_something do
    # implementation
  end
  go_to :next_state

  decision :check_something? do
    condition { some_check }
    if_true :state_a
    if_false :state_b
  end

  wait_until :condition_met? do
    condition { check_something }
    go_to :next_state
  end

  interaction :user_action! do |params|
    # handle user input
  end.when :waiting_state

  result :done
end
```

### Execution Flow
1. Task created/called → ActiveRecord INSERT
2. State transitions → ActiveRecord UPDATE
3. Wait states → Task goes to sleep, ActiveJob schedules wake
4. Background processor → Periodic ActiveJob to wake sleeping tasks
5. Interactions → Direct method call, updates state, wakes task

## V2 Architecture

### Design Principles

1. **DSL Unchanged** - Existing task definitions work without modification
2. **Adapter Pattern** - Pluggable storage and executor backends
3. **Thread-Safe** - Safe for multi-threaded/multi-process deployments
4. **Serialization-Based** - Tasks convert to/from Hash for storage flexibility
5. **Backward Compatible** - ActiveRecord + ActiveJob adapters maintain Rails compatibility
6. **YAGNI (You Aren't Gonna Need It)** - Build concrete implementations first, extract abstractions only when adding second implementation

### Core Concept

The Operations gem implements a **state machine / flowchart pattern** for business logic:

- **Action handlers** - do work, then transition to next state
- **Decision handlers** - evaluate conditions, branch to different states
- **Wait handlers** - sleep until conditions are met or interactions occur
- **Result handlers** - mark task as complete
- **Interactions** - external triggers that wake sleeping tasks

### Configuration System

```ruby
Operations.configure do |config|
  config.storage_adapter = Operations::Storage::Memory.new
  config.executor_adapter = Operations::Executor::Inline.new
end
```

### File Structure

```
lib/
  operations.rb                    # Main entry, Configuration class
  operations/
    task.rb                        # Base Task class with DSL
    handlers/
      action_handler.rb            # Action handler implementation
      decision_handler.rb          # Decision handler implementation
      wait_handler.rb              # Wait handler implementation
      result_handler.rb            # Result handler implementation
      interaction_handler.rb       # Interaction handler implementation
    runner.rb                      # Async runner for standalone operation
    storage/
      base.rb                      # Abstract storage interface
      memory.rb                    # In-memory storage
      active_record.rb             # Rails/AR storage (optional)
    executor/
      base.rb                      # Abstract executor interface
      inline.rb                    # Synchronous execution
      async.rb                     # Async gem execution (optional)
      active_job.rb                # Rails ActiveJob execution (optional)
    errors.rb                      # Error classes
    version.rb
```

## Storage Adapters

### Storage Adapter Interface

All storage adapters must implement:

```ruby
module Operations
  module Storage
    class Base
      # Persist a task, assign ID if new
      # @param task [Operations::Task] the task to save
      # @return [Operations::Task] the saved task
      def save(task)
        raise NotImplementedError
      end

      # Retrieve a task by ID
      # @param id [String] the task ID
      # @return [Operations::Task, nil] the task or nil if not found
      def find(id)
        raise NotImplementedError
      end

      # Find tasks ready to wake (wake_at <= Time.now)
      # @param task_class [Class, nil] optional filter by task class
      # @return [Array<Operations::Task>] tasks ready to wake
      def sleeping_tasks(task_class = nil)
        raise NotImplementedError
      end

      # Find child tasks of a parent task
      # @param task [Operations::Task] the parent task
      # @return [Array<Operations::Task>] child tasks
      def sub_tasks_of(task)
        raise NotImplementedError
      end

      # Delete old tasks
      # @param task_class [Class, nil] optional filter by task class
      # @param before [Time] delete tasks with delete_at before this time
      # @return [Integer] number of tasks deleted
      def delete_old(task_class = nil, before:)
        raise NotImplementedError
      end

      # Convert a model reference for storage
      # @param model [Object] the model to serialize
      # @return [Hash] serialized model reference {id:, type:}
      def serialise_model(model)
        {id: model.id, type: model.class.name}
      end

      # Restore a model reference from storage
      # @param data [Hash] serialized model data {id:, type:}
      # @param class_name [String] the model class name
      # @return [Object] the model instance
      def deserialise_model(data, class_name)
        Object.const_get(class_name).find(data[:id])
      end
    end
  end
end
```

### Memory Storage Adapter

In-memory Hash-based storage for testing and simple single-process apps:

```ruby
module Operations
  module Storage
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
            .select { |data| data[:status] == 'waiting' && data[:wake_at] && data[:wake_at] <= now }
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
```

### ActiveRecord Storage Adapter

For Rails apps, wraps existing ActiveRecord model:

```ruby
module Operations
  module Storage
    class ActiveRecord < Base
      def save(task)
        record = find_or_initialize_record(task)
        record.update!(task.to_h)
        task.id = record.id
        task
      end

      def find(id)
        record = Operations::TaskRecord.find_by(id: id)
        return nil unless record
        restore_task(record.attributes.symbolize_keys)
      end

      def sleeping_tasks(task_class = nil)
        scope = Operations::TaskRecord.where(status: 'waiting').where('wake_at <= ?', Time.now.utc)
        scope = scope.where(type: task_class.name) if task_class
        scope.map { |record| restore_task(record.attributes.symbolize_keys) }
      end

      def sub_tasks_of(task)
        Operations::TaskRecord.where(parent_task_id: task.id)
          .map { |record| restore_task(record.attributes.symbolize_keys) }
      end

      def delete_old(task_class = nil, before:)
        scope = Operations::TaskRecord.where('delete_at <= ?', before)
        scope = scope.where(type: task_class.name) if task_class
        scope.delete_all
      end

      def serialise_model(model)
        # ActiveRecord models can be serialized with their ID
        {id: model.id, type: model.class.name}
      end

      def deserialise_model(data, class_name)
        # Use ActiveRecord to find the model
        Object.const_get(class_name).find(data[:id])
      end

      private

      def find_or_initialize_record(task)
        if task.id
          Operations::TaskRecord.find_or_initialize_by(id: task.id)
        else
          Operations::TaskRecord.new
        end
      end

      def restore_task(data)
        task_class = Object.const_get(data[:type])
        task_class.restore_from(data)
      end
    end
  end
end
```

### Future Storage Adapters

1. **Sequel** - For non-Rails database persistence
2. **PouchDB** - For offline-first browser/Electron apps
3. **Redis** - For distributed systems
4. **CouchDB** - For document-based storage

## Executor Adapters

### Executor Adapter Interface

All executor adapters must implement:

```ruby
module Operations
  module Executor
    class Base
      # Execute a task synchronously, block until complete or sleeping
      # @param task [Operations::Task] the task to execute
      # @return [Operations::Task] the executed task
      def call(task)
        raise NotImplementedError
      end

      # Schedule task for background execution, return immediately
      # @param task [Operations::Task] the task to schedule
      # @return [Operations::Task] the task
      def later(task)
        raise NotImplementedError
      end

      # Resume a sleeping task
      # @param task [Operations::Task] the task to wake
      # @return [Operations::Task] the task
      def wake(task)
        raise NotImplementedError
      end
    end
  end
end
```

### Inline Executor

Everything runs synchronously in current thread:

```ruby
module Operations
  module Executor
    class Inline < Base
      def call(task)
        task.execute_state_machine
        task
      end

      def later(task)
        # In inline mode, just execute immediately
        call(task)
      end

      def wake(task)
        task.status = :active
        call(task)
      end
    end
  end
end
```

### Async Executor

Background execution via async gem fibers:

```ruby
module Operations
  module Executor
    class Async < Base
      def initialize
        @barrier = ::Async::Barrier.new
      end

      def call(task)
        task.execute_state_machine
        task
      end

      def later(task)
        @barrier.async do
          call(task)
        end
        task
      end

      def wake(task)
        task.status = :active
        later(task)
      end

      def wait
        @barrier.wait
      end
    end
  end
end
```

### ActiveJob Executor

Background execution via Rails ActiveJob:

```ruby
module Operations
  module Executor
    class ActiveJob < Base
      def call(task)
        task.execute_state_machine
        task
      end

      def later(task)
        Operations::ExecuteTaskJob.perform_later(task.id, task.class.name)
        task
      end

      def wake(task)
        task.status = :active
        Operations::WakeTaskJob.perform_later(task.id, task.class.name)
        task
      end
    end
  end
end
```

## Task Base Class

### Core Task Implementation

The `Operations::Task` class becomes a plain Ruby object:

```ruby
module Operations
  class Task
    attr_accessor :id, :type, :status, :current_state
    attr_accessor :attributes, :models
    attr_accessor :parent_task_id
    attr_accessor :exception_class, :exception_message, :exception_backtrace
    attr_accessor :created_at, :updated_at, :wake_at, :timeout_at, :delete_at

    def initialize(**attrs)
      @id = attrs[:id]
      @type = self.class.name
      @status = attrs[:status] || :active
      @current_state = attrs[:current_state] || self.class.initial_state
      @attributes = attrs[:attributes] || {}
      @models = attrs[:models] || {}
      @parent_task_id = attrs[:parent_task_id]
      @created_at = attrs[:created_at] || Time.now.utc
      @updated_at = attrs[:updated_at] || Time.now.utc
      @wake_at = attrs[:wake_at]
      @timeout_at = attrs[:timeout_at] || self.class.execution_timeout.from_now
      @delete_at = attrs[:delete_at] || self.class.deletion_time.from_now

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
      Operations.executor.call(task)
      task
    end
    alias_method :perform_now, :call

    def self.later(**attributes)
      task = new(**attributes.merge(status: :waiting))
      Operations.storage.save(task)
      Operations.executor.later(task)
      task
    end
    alias_method :perform_later, :later

    def self.find(id)
      Operations.storage.find(id)
    end

    def execute_state_machine
      previous_state = ""

      while active? && (previous_state != current_state)
        previous_state = current_state
        handler = self.class.handler_for(current_state)

        raise InvalidState, "No handler for state: #{current_state}" unless handler

        handler.call(self)
        Operations.storage.save(self)
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
        self.wake_at = self.class.background_delay.from_now
      end
    end

    def sleep_until_woken
      self.status = :waiting
      self.wake_at = self.class.background_delay.from_now
    end

    def wake_up!
      return call_timeout_handler if timeout_expired?
      Operations.executor.wake(self)
    end

    def complete
      self.status = :completed
    end

    # Status predicates
    def active? = status == :active
    def waiting? = status == :waiting
    def completed? = status == :completed
    def failed? = status == :failed

    # Sub-task methods
    def start(task_class, **attributes)
      task_class.later(**attributes.merge(parent_task_id: id))
    end

    def sub_tasks
      Operations.storage.sub_tasks_of(self)
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

    def in?(state)
      current_state == state.to_s
    end
    alias_method :waiting_until?, :in?

    private

    def record_error!(exception)
      self.status = :failed
      self.exception_class = exception.class.to_s
      self.exception_message = exception.message
      self.exception_backtrace = exception.backtrace&.join("\n")
      Operations.storage.save(self)
    end

    def timeout_expired?
      timeout_at && timeout_at < Time.now.utc
    end

    def call_timeout_handler
      handler = self.class.timeout_handler
      if handler
        instance_exec(&handler)
      else
        raise Operations::Timeout.new("Timeout expired", self)
      end
    end

    def serialize_models
      models.transform_values do |value|
        if value.is_a?(Array)
          value.map { |v| Operations.storage.serialise_model(v) }
        else
          Operations.storage.serialise_model(value)
        end
      end
    end

    def deserialize_models(serialized_models)
      serialized_models.transform_values do |value|
        if value.is_a?(Array)
          value.map { |v| Operations.storage.deserialise_model(v, v[:type]) }
        else
          Operations.storage.deserialise_model(value, value[:type])
        end
      end
    end
  end
end
```

### DSL Module

The DSL remains unchanged from V1:

```ruby
module Operations
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
        model_definitions[name] = class_name || name.to_s.classify

        define_method(name) do
          @models[name.to_s]
        end

        define_method("#{name}=") do |value|
          @models[name.to_s] = value
        end
      end

      def has_models(name, class_name = nil)
        models_definitions[name] = class_name || name.to_s.singularize.classify

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
    end

    def validate!
      self.class.validation_rules.each do |attr, rules|
        value = send(attr)

        if rules[:presence] && (value.nil? || value == "")
          raise Operations::ValidationError, "#{attr} is required"
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

# Include DSL in Task base class
class Operations::Task
  include Operations::DSL
end
```

## Handler Classes

### Action Handler

```ruby
module Operations
  module Handlers
    class ActionHandler
      attr_accessor :next_state

      def initialize(name, &action)
        @name = name.to_sym
        @action = action
        @next_state = nil
      end

      def then(next_state)
        @next_state = next_state
        self
      end

      def immediate?
        true
      end

      def call(task)
        task.instance_exec(&@action)
        task.go_to(@next_state) if @next_state
      end
    end
  end
end
```

### Decision Handler

```ruby
module Operations
  module Handlers
    class DecisionHandler
      def initialize(name, &config)
        @name = name.to_sym
        @conditions = []
        @destinations = []
        @true_state = nil
        @false_state = nil
        instance_eval(&config) if block_given?
      end

      def immediate?
        true
      end

      def condition(&block)
        @conditions << block
      end

      def go_to(destination)
        @destinations << destination
      end

      def if_true(state)
        @true_state = state
      end

      def if_false(state)
        @false_state = state
      end

      def call(task)
        if has_true_false_handlers?
          handle_boolean_decision(task)
        else
          handle_multiple_conditions(task)
        end
      end

      private

      def has_true_false_handlers?
        !@true_state.nil? || !@false_state.nil?
      end

      def handle_boolean_decision(task)
        result = task.instance_eval(&@conditions.first)
        next_state = result ? @true_state : @false_state
        task.go_to(next_state)
      end

      def handle_multiple_conditions(task)
        condition = @conditions.find { |c| task.instance_eval(&c) }
        raise Operations::NoDecision, "No conditions matched in #{@name}" unless condition

        index = @conditions.index(condition)
        task.go_to(@destinations[index])
      end
    end
  end
end
```

### Wait Handler

```ruby
module Operations
  module Handlers
    class WaitHandler < DecisionHandler
      def immediate?
        false
      end

      def call(task)
        # Try to evaluate conditions
        begin
          super
        rescue Operations::NoDecision
          # If no conditions match, task sleeps
          task.sleep_until_woken
        end
      end
    end
  end
end
```

### Interaction Handler

```ruby
module Operations
  module Handlers
    class InteractionHandler
      def initialize(name, task_class, &implementation)
        @name = name.to_sym
        @task_class = task_class
        @implementation = implementation
        @valid_states = []

        # Define the interaction method on the task class
        task_class.define_method(name) do |*args|
          handler = self.class.interaction_handler_for(@name.to_s)
          handler.call(self, *args)
        end
      end

      def when(*states)
        @valid_states = states.map(&:to_s)
        self
      end

      def immediate?
        true
      end

      def call(task, *args)
        unless @valid_states.empty? || @valid_states.include?(task.current_state)
          raise Operations::InvalidState,
            "Cannot call #{@name} when in state #{task.current_state}"
        end

        task.instance_exec(*args, &@implementation)

        if task.waiting?
          task.wake_up!
        end
      end
    end
  end
end
```

### Result Handler

```ruby
module Operations
  module Handlers
    class ResultHandler
      def initialize(name)
        @name = name.to_sym
      end

      def immediate?
        true
      end

      def call(task)
        task.complete
      end
    end
  end
end
```

## Runner

The Runner is a **delegator** that handles periodic task waking and cleanup, delegating execution to the configured executor. This means you can use the same runner script whether using ActiveJob, Async, or Inline executors.

```ruby
module Operations
  class Runner
    def initialize(
      wake_interval: 30,      # Wake sleeping tasks every 30 seconds
      cleanup_interval: 3600  # Clean old tasks every hour
    )
      @wake_interval = wake_interval
      @cleanup_interval = cleanup_interval
      @running = false
    end

    def start
      @running = true

      loop do
        break unless @running

        wake_sleeping_tasks
        delete_old_tasks if should_cleanup?

        sleep @wake_interval
      end
    end

    def stop
      @running = false
    end

    private

    def wake_sleeping_tasks
      tasks = Operations.storage.sleeping_tasks

      tasks.each do |task|
        begin
          # Delegate to configured executor
          Operations.executor.wake(task)
        rescue => e
          warn "Error waking task #{task.id}: #{e.message}"
        end
      end

      tasks.count
    end

    def delete_old_tasks
      return unless should_cleanup?

      count = Operations.storage.delete_old(before: Time.now.utc)
      warn "Deleted #{count} old tasks" if count > 0
      @last_cleanup = Time.now
      count
    end

    def should_cleanup?
      @last_cleanup.nil? || (Time.now - @last_cleanup) >= @cleanup_interval
    end
  end
end
```

### Usage Examples

**With Async executor:**

```ruby
# bin/operations-runner
require 'operations'
require 'operations/runner'

Operations.configure do |config|
  config.storage_adapter = Operations::Storage::Memory.new
  config.executor_adapter = Operations::Executor::Async.new
end

runner = Operations::Runner.new(wake_interval: 30, cleanup_interval: 3600)
runner.start
```

**With ActiveJob executor:**

```ruby
# bin/operations-runner (Rails app)
require_relative '../config/environment'

# Configuration in config/initializers/operations.rb sets ActiveJob executor
runner = Operations::Runner.new(wake_interval: 30)
runner.start
```

**With Inline executor (testing):**

```ruby
# spec/support/operations_runner.rb
RSpec.configure do |config|
  config.before(:suite) do
    Thread.new do
      Operations::Runner.new(wake_interval: 1).start
    end
  end
end
```

### Multi-Process Scaling

For production deployments with Async executor, use async-container:

```ruby
require 'async/container'
require 'operations/runner'

container = Async::Container.new

# Run 4 worker processes
4.times do |i|
  container.run(name: "worker-#{i}") do
    runner = Operations::Runner.new
    runner.start
  end
end

container.wait
```

**Key benefit:** The same `Operations::Runner` works with any executor. Switch from ActiveJob to Async by changing configuration, not code.

## Configuration

```ruby
# lib/operations.rb
module Operations
  class << self
    attr_writer :storage_adapter, :executor_adapter

    def configure
      yield self
    end

    def storage
      @storage_adapter ||= Storage::Memory.new
    end
    alias_method :storage_adapter, :storage

    def executor
      @executor_adapter ||= Executor::Inline.new
    end
    alias_method :executor_adapter, :executor
  end
end
```

### Rails Configuration

```ruby
# config/initializers/operations.rb
require 'operations/storage/active_record'
require 'operations/executor/active_job'

Operations.configure do |config|
  config.storage_adapter = Operations::Storage::ActiveRecord.new
  config.executor_adapter = Operations::Executor::ActiveJob.new
end
```

### Standalone Configuration

```ruby
# config/operations.rb
require 'operations'

Operations.configure do |config|
  config.storage_adapter = Operations::Storage::Memory.new
  config.executor_adapter = Operations::Executor::Inline.new
end
```

## Testing Strategy

### RSpec Integration

The existing `test` method continues to work:

```ruby
RSpec.describe MyTask do
  it "transitions from start to done" do
    task = MyTask.test :start, name: "Alice"
    expect(task).to be_in :done
  end

  it "handles decision branches" do
    task = MyTask.test :check_status, status: "active"
    expect(task).to be_in :process_active

    task = MyTask.test :check_status, status: "inactive"
    expect(task).to be_in :process_inactive
  end
end
```

### Test Configuration

```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.before(:each) do
    # Use memory adapter for fast, isolated tests
    Operations.configure do |c|
      c.storage_adapter = Operations::Storage::Memory.new
      c.executor_adapter = Operations::Executor::Inline.new
    end
  end
end
```

### Testing Custom Matchers

Keep the existing matchers from V1:

```ruby
# lib/operations/matchers.rb
RSpec::Matchers.define :be_in do |expected_state|
  match do |task|
    task.current_state == expected_state.to_s
  end

  failure_message do |task|
    "expected task to be in state #{expected_state}, but was in #{task.current_state}"
  end
end

RSpec::Matchers.define :be_completed do
  match do |task|
    task.completed?
  end
end

RSpec::Matchers.define :be_failed do
  match do |task|
    task.failed?
  end
end
```

## Migration Strategy

### For Existing V1 Users

1. **Update Gemfile**
   ```ruby
   # Before
   gem 'standard_procedure_operations', '~> 0.7'

   # After
   gem 'standard_procedure_operations', '~> 2.0'
   gem 'operations-activerecord', '~> 2.0'  # For Rails apps
   gem 'operations-activejob', '~> 2.0'     # For background jobs
   ```

2. **Add Configuration**
   ```ruby
   # config/initializers/operations.rb (new file)
   Operations.configure do |config|
     config.storage_adapter = Operations::Storage::ActiveRecord.new
     config.executor_adapter = Operations::Executor::ActiveJob.new
   end
   ```

3. **Task Migration**
   - Task code requires **no changes**
   - DSL is 100% backward compatible
   - Existing tests continue to work

4. **Database**
   - Existing `operations_tasks` table can be reused
   - May need to add/remove columns based on V2 schema

### Breaking Changes

1. **No ApplicationRecord inheritance** - Tasks are POROs
2. **No direct ActiveRecord methods** - Use storage adapter instead
3. **Configuration required** - Must set up adapters explicitly

### Compatibility Layer (Optional)

For gradual migration, provide a compatibility shim:

```ruby
# gem 'operations-compat', '~> 2.0'
module Operations
  class Task
    # Add Rails-like methods for compatibility
    def save! = Operations.storage.save(self)
    def reload = Operations.storage.find(id)
    def destroy = Operations.storage.delete(id)

    def self.find_by(attributes)
      # Limited find_by support
    end
  end
end
```

## Development Phases

Following **YAGNI (You Aren't Gonna Need It)** principles, we build concrete implementations first, then extract abstractions only when needed.

### Phase 1: Core Working Implementation (Weeks 1-3)

**Goal:** Remove Rails dependencies and prove the DSL still works

- [ ] Set up gem structure without Rails Engine
- [ ] Implement core Task class as PORO with serialization (`to_h`/`restore_from`)
- [ ] Build DSL module with all existing DSL methods
- [ ] Create handler classes (Action, Decision, Wait, Result, Interaction)
- [ ] Implement state machine execution logic
- [ ] **Build concrete Memory storage (no abstraction yet)** - simple Hash-based storage
- [ ] **Build concrete Inline executor (no abstraction yet)** - direct synchronous execution
- [ ] **Port ALL existing V1 tests** - prove DSL is backward compatible
- [ ] **Add simple configuration** - `Operations.storage = MemoryStorage.new`

**Success criteria:** All V1 tests pass with Memory + Inline implementations

**Why this phase is testable:** We have working storage and execution, so we can actually run tasks and verify behavior.

### Phase 2: Extract Abstractions + ActiveRecord (Weeks 4-5)

**Goal:** Extract adapter pattern when we need a second implementation

- [ ] Extract `Storage::Base` interface from Memory implementation
- [ ] Refactor Memory to implement Base interface
- [ ] Build ActiveRecord storage adapter implementing Base
- [ ] Extract `Executor::Base` interface from Inline implementation
- [ ] Refactor Inline to implement Base interface
- [ ] Update configuration to `Operations.configure` block
- [ ] Test both storage adapters with same test suite
- [ ] Ensure thread-safety in Memory adapter

**Success criteria:** Can swap between Memory and ActiveRecord storage seamlessly

**Why extract now:** We have two implementations, so we know what the abstraction needs to support.

### Phase 3: Additional Executors (Week 6)

**Goal:** Add async execution options

- [ ] Build Async executor implementing Executor::Base
- [ ] Build ActiveJob executor implementing Executor::Base
- [ ] Create Jobs for ActiveJob executor (ExecuteTaskJob, WakeTaskJob)
- [ ] Add executor tests
- [ ] Verify all executor types work with both storage types

**Success criteria:** Can run tasks with any combination of storage + executor

### Phase 4: Runner & Background Processing (Week 7)

**Goal:** Enable standalone operation

- [ ] Implement Operations::Runner using async gem
- [ ] Add wake_sleeping_tasks functionality
- [ ] Add delete_old_tasks functionality
- [ ] Add runner tests
- [ ] Document runner usage
- [ ] Test runner with different adapter combinations

**Success criteria:** Can run standalone process that wakes tasks and cleans up old data

### Phase 5: Documentation & Examples (Weeks 8-9)

**Goal:** Make V2 usable

- [ ] Update README for V2
- [ ] Write migration guide from V1 to V2
- [ ] Write adapter development guide
- [ ] Create example Rails app using ActiveRecord + ActiveJob
- [ ] Create example standalone app using Memory + Async
- [ ] Add API documentation
- [ ] Port RSpec matchers and ensure `test` method is documented

**Success criteria:** Someone can upgrade from V1 or start fresh with V2 using docs

### Phase 6: External Adapter Gems (Weeks 10-11)

**Goal:** Separate optional dependencies

- [ ] Extract operations-activerecord gem
- [ ] Extract operations-activejob gem
- [ ] Extract operations-async gem
- [ ] Update core gem to remove optional dependencies
- [ ] Document each adapter gem
- [ ] Test installation and configuration of each gem

**Success criteria:** Core gem has zero Rails dependencies, adapters are opt-in

### Phase 7: Polish & Beta (Week 12)

**Goal:** Production ready

- [ ] Performance testing (compare to V1)
- [ ] Security audit
- [ ] Fix any issues found in beta testing
- [ ] Final documentation review
- [ ] Beta release for community testing

**Success criteria:** No regressions, performance >= V1

### Phase 8: Stable Release (Week 13)

**Goal:** Ship it!

- [ ] Address beta feedback
- [ ] Finalize CHANGELOG
- [ ] Release 2.0.0 stable
- [ ] Announce release
- [ ] Monitor for issues

**Success criteria:** V2 is released and stable

## Success Criteria

V2 will be considered successful when:

1. ✅ Core gem has **zero Rails dependencies**
2. ✅ All V1 DSL features work **identically**
3. ✅ Memory and Inline adapters work perfectly for simple cases
4. ✅ ActiveRecord and ActiveJob adapters provide full Rails compatibility
5. ✅ Async adapter enables efficient concurrent execution
6. ✅ All existing V1 tests pass with appropriate adapters
7. ✅ Performance is equal to or better than V1
8. ✅ Documentation is comprehensive and clear
9. ✅ Migration path is straightforward
10. ✅ Thread-safe for multi-threaded applications

## Future Enhancements

After V2 stable release:

1. **Additional Storage Adapters**
   - Sequel (non-Rails database)
   - Redis (distributed systems)
   - PouchDB (offline-first apps)
   - CouchDB (document storage)
   - PostgreSQL with LISTEN/NOTIFY

2. **Additional Executor Adapters**
   - Sidekiq (direct integration)
   - GoodJob (Rails native)
   - Resque (Redis-backed)

3. **Observability**
   - Structured logging
   - Metrics collection
   - OpenTelemetry integration
   - Task visualization

4. **Developer Tools**
   - Web UI for task inspection
   - CLI for task management
   - GraphViz export for workflows
   - Task debugging tools

5. **Advanced Features**
   - Task versioning
   - Task migration tools
   - Distributed task coordination
   - Task priority queues

## References

- **async-container** - <https://github.com/socketry/async-container>
  - Inspiration for runner pattern
  - Controller (lifecycle), Container (process management), Group (child tracking), Notify (readiness)
  - Used by Falcon web server for multi-process scaling

- **Current Operations Gem** - <https://github.com/standard-procedure/operations>
  - V1 implementation for reference

## Conclusion

Operations V2 represents a fundamental shift from a Rails-specific engine to a framework-agnostic Ruby gem with pluggable adapters. By maintaining the elegant DSL while removing framework dependencies, we enable the gem to serve a much wider range of use cases:

- **Rails applications** - Use ActiveRecord + ActiveJob adapters
- **Sinatra/Hanami apps** - Use Sequel + Async adapters
- **Microservices** - Use Redis + Async adapters
- **Desktop/Electron apps** - Use PouchDB + Inline adapters
- **Testing** - Use Memory + Inline adapters

The development approach follows **YAGNI principles**: Phase 1 delivers a working, testable implementation with Memory storage and Inline execution. Only in Phase 2, when adding ActiveRecord support, do we extract the adapter interfaces. This ensures Phase 1 is testable (all V1 tests can run) and prevents over-engineering.

The adapter architecture ensures applications only include dependencies they need, while the unchanged DSL means existing V1 users can migrate smoothly. This plan provides a clear roadmap for development with realistic timelines (13 weeks) and measurable success criteria at each phase.
