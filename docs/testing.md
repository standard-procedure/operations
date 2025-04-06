# Testing

Because operations are intended to model long, complex, flowcharts of decisions and actions, it can be a pain coming up with the combinations of inputs to test every path through the sequence.  

Instead, you can test each state handler _in isolation_.  

As the handlers are stateless, we can call one without hitting the database; instead creating a dummy task object and then triggering the handler with the correct parameters.  

This is done by calling `handling`, which yields a `test` object that we can inspect.

### Testing state transitions
To test if we have moved on to another state (for actions or decisions):
```ruby
MyOperation.handling(:an_action_or_decision, some: "data") do |test|
  assert_equal test.next_state, "new_state"
  # or
  expect(test).to have_moved_to "new_state"
end
```

### Testing data modifications
To test if some data has been set or modified (for actions):
```ruby
MyOperation.handling(:an_action, existing_data: "some_value") do |test|
  # has an existing data value been modified?
  assert_equal test.existing_data, "some_other_value"
  # or
  expect(test.existing_data).to eq "some_other_value"
  # has a new data value been added?
  assert_equal test.new_data, "new_value"
  # or
  expect(test.new_data).to eq "new_value"
end
```

### Testing results
To test the results from a result handler:
```ruby
MyOperation.handling(:a_result, some: "data") do |test|
  assert_equal test.outcome, "everything is as expected"
  # or
  assert_equal test[:outcome], "everything is as expected"
  # or
  expect(test.outcome).to eq "everything is as expected"
  # or
  expect(test[:outcome]).to eq "everything is as expected"
end
```
(Note - although results are stored in the database as a Hash, within your test, the results object is still carried as an OpenStruct, so you can access it using either notation).

### Testing sub-tasks 
```ruby 
MyOperation.handling(:a_sub_task, some: "data") do |test|
  # Test which sub-tasks were called
  assert_includes test.sub_tasks.keys, MySubTask
  # or 
  expect(test.sub_tasks).to include MySubTask
end
```
TODO: I'm still figuring out how to test the data passed to sub-tasks.  And calling a sub-task will actually execute that sub-task, so you need to stub `MySubTask.call` if it's an expensive operation.  

```ruby 
# Sorry, don't know the Minitest syntax for this
@sub_task = double "Operations::Task", results: { some: "answers" }
allow(MySubTask).to receive(:call).and_return(@sub_task)

MyOperation.handling(:a_sub_task, some: "data") do |test|
  expect(test.sub_tasks).to include MySubTask
end
```
### Testing failures 
To test if a handler has failed:
```ruby

expect { MyOperation.handling(:a_failure, some: "data") }.to raise_error(SomeException)
```

If you are using RSpec, you must `require "operations/matchers"` to make the matchers available to your specs.  
