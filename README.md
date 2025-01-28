# Operations
Build your business logic operations in an easy to understand format.  

Most times when I'm adding a feature to a complex application, I tend to end up drawing a flowchart.  

"We start here, then we check that option and if it's true then we do this, if it's false then we do that"

In effect, that flowchart is a state machine - with "decision states" and "action states".  And Operations is intended to be a way of designing your ruby class so that flowchart becomes easy to follow.  

## Usage
Here's a simplified example from [Collabor8Online](https://www.collabor8online.co.uk) - in C8O when you download a document, we need to check your access rights, as well as ensuring that the current user has not breached their monthly download limit.  In addition, some accounts have a "filename scrambler" switched on - where the original filename is replaced (which is a feature used by some of our clients on their customers' trial accounts).  

### Defining an operation
The flowchart, for this simplified example, is something like this: 

```
START -> CHECK AUTHORISATION
         Is this user authorised?
         NO -> FAIL
         YES -> CHECK DOWNLOAD LIMITS

         CHECK DOWNLOAD LIMITS
         Is this user within their monthly download limit?
         NO -> FAIL
         YES -> CHECK FILENAME SCRAMBLER

         CHECK FILENAME SCRAMBLER
         Is the filename scrambler switched on for this account?
         NO -> PREPARE DOWNLOAD
         YES -> SCRAMBLE FILENAME

         SCRAMBLE FILENAME
         Replace the filename with a scrambled one
         THEN -> PREPARE DOWNLOAD

         PREPARE DOWNLOAD
         Get the document's download URL and filename and return it as the results of this operation
         DONE
```

We have five states - three of which are decisions, one is an action and one is a result.  

Here's how this would be represented using Operations.  

```ruby
class PrepareDocumentForDownload < Operations::Task
  starts_with :authorised?

  decision :authorised? do
    if_true :within_download_limits?
    if_false { fail_with "unauthorised" }
  end

  decision :within_download_limits? do
    if_true :use_filename_scrambler?
    if_false { fail_with "download_limit_reached" }
  end

  decision :use_filename_scrambler? do
    condition { use_filename_scrambler }
    if_true :scramble_filename
    if_false :prepare_download
  end

  action :scramble_filename do
    self.filename = "#{Faker::Lorem.word}#{File.extname(document.filename.to_s)}"
    go_to :prepare_download
  end

  result :prepare_download do |results|
    results[:filename] = filename || document.filename.to_s
  end

  private def authorised?(data) = data.user.can?(:read, data.document)
  private def within_download_limits?(data) = data.user.within_download_limits?
end
```

### Decisions
A decision handler evaluates a condition, then changes state depending upon if the result is true or false. 

```ruby
decision :is_it_the_weekend? do 
  condition { |_| Date.today.wday.in? [0, 6] }
  if_true :have_a_party 
  if_false :go_to_work
end
```

The condition can alternatively be evaluated by a method with the same name as the decision.  

```ruby
decision :is_it_the_weekend? do 
  if_true :have_a_party 
  if_false :go_to_work
end

def is_it_the_weekend?(_)
  Date.today.wday.in? [0, 6]
end
```

A decision can also mark a failure, which will terminate the task.  

```ruby
decision :authorised? do 
  if_true :do_some_work 
  if_false { fail_with "Unauthorised" }
end
```

### Actions
An action handler does some work, then moves to another state.  

```ruby 
action :have_a_party do |data|
  data[:food] = buy_some_food_for(data[:number_of_guests])
  data[:beer] = buy_some_beer_for(data[:number_of_guests])
  data[:music] = plan_a_party_playlist
  go_to :send_invitations, data
end
```

You must pass your `data` on to the next state or it will be lost.  And if you omit the `go_to` from your action handler, the operation will stop whilst still being marked as in progress.  

### Results
A result handler marks the end of an operation, optionally returning some results.  

```ruby
result :send_invitations do |data, results|
  results[:invited_friends] = (0..data[:number_of_guests]).collect do |i|
    friend = data[:friends].pop
    FriendsMailer.with(recipient: friend).party_invitation.deliver_later
    friend 
  end
end
```

The task will then be marked as `completed?`, the task's state will be `send_invitations` and `results[:invited_friends]` will contain an array of the people you sent invitations to.  

If you don't have any meaningful results, you can omit the block on your result handler.  

```ruby
result :go_to_work
```

In this case, the task will be marked as `completed?`, the task's state will be `go_to_work` and `results` will be an empty hash.  

### Calling an operation
You would use this [PrepareDocumentForDownload](spec/examples/prepare_document_for_download_spec.rb) operation like so:

```ruby
class DownloadsController < ApplicationController 
  def show 
    @document = Document.includes(:account).find(params[:id])
    @task = PrepareDocumentForDownload.call(user: Current.user, document: @document, use_filename_scrambler: true)
    if @task.completed?
      @filename = @task.results[:filename]
      send_data @document.contents, filename: @filename, disposition: "attachment"
    else
      render action: "error", message: @task.results[:failure_message], status: 401
    end
  end
end
```

OK - so that's a pretty longwinded way of performing a simple task.  But, in Collabor8Online, the actual operation for handling downloads has over twenty states, with half of them being decisions - so being able to lay out the state transitions in this way definitely helps comprehension of what is going on.  

### Data and results
Each operation carries its own, mutable, data for the duration of the operation.  

This is provided when you `call` the operation to start it and is passed through to each decision, action and result.  If you modify the data then that modification is passed on to the next handler.  For example, the `filename` in the [PrepareDocumentForDownload example](spec/examples/prepare_document_for_download_spec.rb) is blank when the operation is started, but may be set if the `scramble_filename` action is called.  The final `prepare_download` result then examines it to see if it should use the scrambled filename or the original one from the document.  

This data is transient and not stored in the database.  

Within handlers implemented as blocks, you can read the data directly - for example, `condition { use_filename_scrambler }` from the `use_filename_scrambler?` decision shown earlier.  If you want to modify a value, or add a new one, you must use `self` - `self.filename = "myfile.txt"`.  This is because the data is carried using a [DataCarrier](/app/models/operations/task/data_carrier.rb) object and `instance_eval` is used within your block handlers.  This also means that block handlers cannot access any methods or data on the task object itself (apart from calling `go_to` and `fail_with`).  

Within handlers implemented as methods, these are defined on the task itself, so can access other methods and data available there.  Each method takes a `data` parameter that can be accessed, either as a hash - `data[:some_field]` - or as an attribute - `data.some_field`.  

The final `results` data from any `result` handlers is stored, along with the task, in the database, so it can be examined later.  It is encoded into JSON, but any ActiveRecord models are translated using a [GlobalID](https://github.com/rails/globalid) by using the same mechanism as ActiveJob ([ActiveJob::Arguments](https://guides.rubyonrails.org/active_job_basics.html#supported-types-for-arguments)).  Be aware that if you do store an ActiveRecord model into your `results`, then that model is later deleted from the database, your task's `results` will be unavailable, as the `GlobalID::Locator` will fail when it tries to load the record.  However, the deserialisation routine will return the JSON string as `results[:raw_data]`.

### Failures and exceptions

If any handlers raise an exception, the task will be terminated. It will be marked as `failed?` and the `results` hash will contain `results[:exception_message]`, `results[:exception_class]` and `results[:exception_backtrace]` for the exception's message, class name and backtrace respectively.  

You can also stop a task at any point by calling `fail_with message`.  This will mark the task as `failed?` and the `reeults` has will contain `results[:failure_message]`.

### Status messages

### Background operations and pauses

Coming soon.  


## Installation
Add this line to your application's Gemfile:

```ruby
gem "standard_procedure_operations"
```

Then create your own operations by inheriting from `Operations::Task`.

```ruby
class MyOperation < Operations::Task
  starts_with :am_i_awake?

  decision :am_i_awake? do 
    if_true :awake 
    if_false :asleep
  end 

  result :awake 
  result :asleep

  def am_i_awake? = true
end
```

## License
The gem is available as open source under the terms of the [LGPL License](/LICENSE).  This may or may not make it suitable for your needs
