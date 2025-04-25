# Agents

An Agent is a Task that runs in the background and can respond to external interactions.  

An example of an agent is a user registration process: 

```ruby
class UserRegistration < Operations::Agent
  timeout 24.hours
  frequency 1.minute

  inputs :email, :name
  starts_with :create_user_and_send_registration_email

  action :create_user do 
    self.user = User.create! email: email, name: name
    self.registration_completed? = false
    UserMailer.with(user: user, registration_task: task).registration.deliver_now 
  end
  go_to :user_has_registered?

  wait_until :user_has_registered? do 
    condition { registration_completed? }
    go_to :send_welcome_email
  end

  action :send_welcome_email do 
    UserMailer.with(user: user).welcome.deliver_now
  end
  go_to :done 

  result :done

  interaction :register_user! do |params|
    user.update! params
    self.registration_completed? = true 
  end.when :user_has_registered?

  on_timeout do 
    AdministratorMailer.with(user: user).user_did_not_complete_registration.deliver_now 
  end
end
```

We define the task as normal, but inherit from `Operations::Agent` and have two new declarations - `timeout` and `frequency`.  The `timeout` defines how long the agent will live for, the `frequency` defines how often the agent will "wake up" if it is waiting.  

The task has an action defined as usual but then it moves into a new type of `state` - a "wait handler".   The wait handler is the key to how an agent works and allows the agent to respond to interactions from the outside world.  In this example, the agent is waiting for the user to complete their registration (which is done via an "interaction", `register_user!`).

## Starting an agent

Agents are not `call`ed, instead they are `start`ed.  This returns a reference to the task and performs its actions and decisions as normal - until it reaches a "wait_handler".  At this point, it checks the wait handler's conditions and if none are met, it moves into a `waiting` status, where it goes to sleep until `frequency` time has passed.  

```ruby
task = UserRegistration.call email: "alice@example.com", name: "Alice Aardvark"
puts task.status # => waiting
```

## Wait handlers

The wait handler is similar to a decision handler; it evaluates a number of conditions and if the condition is met, it moves to another state.  Unlike a decision handler, if none of the conditions are met, then the agent does not fail - instead it remains in the current state and sleeps until the `frequency` time has passed.  Once awoken it checks the conditions again or it times out.  

## Interactions

Interactions are ways for the agent to respond to external events.  

In this example, when the user clicks the registration link in their email, we pass the agent ID, not the user ID.  The controller extracts the user from the agent, then displays the registration form.  When the form is submitted the controller calls the `register_user!` interaction, passing in the `params` from the form.  This wakes the agent, updates the user record, sets its internal state and immediately reevaluates the wait handler.  The wait handler moves the agentto the `send_welcome_email` state, which is performed immediately, and moves to `done`.  

```ruby
class UserRegistrationController < ApplicationController
  def edit 
    @user_registration = UserRegistration.find params[:id]
    @user = @user_registration.data[:user]
  end 

  def update
    @user_registration = UserRegistration.find params[:id]

    @user_registration.register_user! params: user_registration_params

    redirect_to dashboard_path
  end
end
```

Interactions are similar to defining a method on the agent but they have three advantages.  

- The interaction works within the context of the data-carrier - so the interaction has access to the internal data belonging to the agent.  
- The interaction can, optionally, only be called when the agent is in the correct state - as can be seen by the `when` clause at the end of the interaction.  If `UserRegistrationController#update` was called _after_ the user has completed the registration process, the call will fail.
- The interaction invokes the wait handler and any subsequent handlers immediately.  This agent has a `frequency` of `1.minute` so only wakes up 60 times per hour.  But an interaction allows the agent to respond when the user registers, not at some point in the future.  

### Interactions and states

Each interaction can restrict the states in which it can be called with a `when` clause: 

```ruby
  interaction :register_user! do |params|
    user.update! params
    self.registration_completed? = true 
  end.when :user_has_registered?
```
If no `when` clause is attached then the interaction can be called in any state.  

## Task runner

Agents use a separate process to wake them up, implemented as a long running `rake` task - `operations:task_runner`.  The task runner checks the current agents, looking for those which have timed out or those which are ready to wake up.  If an agent is ready to wake up, it schedules an ActiveJob to perform the wait handler and any subsequent state transitions.  If the agent has timed out, if calls the `on_timeout` handler.  

## Waiting for sub-tasks to complete

If one of your actions starts sub-tasks, you can add a `wait_handler` that waits until those sub-tasks have completed.  This allows you to spread their execution across multiple processes or even servers (depending upon how your job queue processes are configured).

```ruby
class ParallelTasks < Operations::Task 
  inputs :number_of_sub_tasks
  starts_with :start_sub_tasks 
  
  action :start_sub_tasks do 
    self.sub_tasks = (1..number_of_sub_tasks).collect { |i| start LongRunningTask, number: i }
  end
  go_to :do_something_else

  action :do_something_else do 
    # do something else while the sub-tasks do their thing
  end
  go_to :sub_tasks_completed?

  wait_until :sub_tasks_completed? do 
    condition { sub_tasks.all? { |t| t.completed? } }
    go_to :done
  end 

  result :done 
end

@task = ParallelTasks.start number_of_sub_tasks: 5
```
The principle is the same as above; we store the newly created sub-tasks in our own `data` property.  As they are ActiveRecord models, they get reloaded each time `sub_tasks_completed?` is evaluated - and we check to see that they have all completed before moving on.  

## Delays

When an agent is waiting, the task runner will periodically wake it up so it can evaluate its wait handler.  By default this happens every 5 minutes, but can be overridden by specifying the `delay`.  

## Timeouts

It's possible for an agent to get stuck.  In the sub-tasks example above, if one of the sub-tasks fails, waiting for them _all_ to complete will never happen.  Every operation has a default timeout of 24 hours - if the operation has not completed or failed 24 hours after it was initially started, it will fail with an `Operations::Timeout` exception.  

If you need to change this (such as the user verification example above), you can declare the timeout when defining the operation.  

```ruby
class UserRegistration < Operations::Task 
  timeout 24.hours 
  delay 15.minutes
  ...
end
```

Instead of failing with an `Operations::Timeout` exception, you define an `on_timeout` handler for any special processing should the time-out occur.  If a timeout handler is defined, the agent does not fail (unless an exception is raised in your timeout handler) and the timeout is reset.  

```ruby 
class WaitForSomething < Operations::Task 
  timeout 10.minutes 
  delay 1.minute 

  on_timeout do 
    Notifier.send_timeout_notification
  end
end
```
