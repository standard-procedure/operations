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
    interactions :user_has_registered!
  end

  action :send_welcome_email do 
    UserMailer.with(user: user).welcome.deliver_now
  end
  go_to :done 

  result :done

  interaction :user_has_registered! do |params|
    user.update! params
    self.registration_completed? = true 
  end

  on_timeout do 
    AdministratorMailer.with(user: user).user_did_not_complete_registration.deliver_now 
  end
end
```

We define the task as normal, but inherit from `Operations::Agent` and have two new declarations - `timeout` and `frequency`.  The `timeout` defines how long the agent will live for, the `frequency` defines how often the agent will "wake up" and perform some action.  

The task has an action defined as usual but then it moves into a new type of `state` - a "wait handler".   The wait handler is the key to how an agent works and allows the agent to respond to interactions from the outside world.  In this example, whilst the agent is waiting for the user to register, it allows an interaction called `user_has_registered!`.  

## Starting an agent

Agents are not `call`ed, instead they are `start`ed.  This returns a reference to the task and performs the initial state handler (in this example, `create_user_and_send_registration_email`).  Then it moves into a `waiting` status, where it goes to sleep until `frequency` time has passed.  

```ruby
task = UserRegistration.call email: "alice@example.com", name: "Alice Aardvark"
puts task.status # => waiting
```

## Wait handlers

The wait handler is similar to a decision handler; it evaluates a number of conditions and if the condition is met, it moves to another state.  Unlike a decision handler, if none of the conditions are met, then the agent does not fail - instead it remains in the current state and sleeps until the `frequency` time has passed.  Once awoken it checks the conditions again or it times out.  

Wait handlers also declare which interactions are permitted and these are key to how the agent responds to the outside world.  

## Interactions

Interactions are ways for the agent to respond to external events.  

In this example, when the user clicks the registration link in their email, we pass the agent ID, not the user ID.  The controller extracts the user from the agent, then displays the registration form.  When the form is submitted the controller calls the `user_has_registered!` interaction, passing in the `params` from the form.  completes the registration form, the controller gathers the parameters from the form and calls the `user_has_registered!` interaction on the agent.  This wakes the agent, which updates the user record, sets its internal state and immediately reevaluates the wait handler, which moves it to the `send_welcome_email` state.  

```ruby
class UserRegistrationController < ApplicationController
  def edit 
    @user_registration = UserRegistration.find params[:id]
    @user = @user_registration.data[:user]
  end 

  def update
    @user_registration = UserRegistration.find params[:id]

    @user_registration.user_has_registered! params: user_registration_params

    redirect_to dashboard_path
  end
end
```

You could define the interaction as a method on the `UserRegistration` class, but interactions have three advantages.  

- The interaction works within the context of the data-carrier - so the interaction has access to the internal data belonging to the agent.  
- The interaction can only be called when the agent is in the correct state.  If `UserRegistrationController#update` was called _after_ the user has completed the registration process, the call will fail.
- The interaction invokes the wait handler immediately.  This agent has a `frequency` of `1.minute` so only wakes up 60 times per hour.  But an interaction allows the agent to respond immediately.  

## Task runner

Agents use a separate process to wake them up, implemented as a long running `rake` task - `operations:task_runner`.  The task runner checks the current agents, looking for those which have timed out or those which are ready to wake up.  If an agent is ready to wake up, it schedules an ActiveJob to perform the wait handler and any subsequent state transitions.  If the agent has timed out, if calls the `on_timeout` handler.  


#### Waiting for sub-tasks to complete
Alternatively, you may have a number of sub-tasks that you want to run in parallel then continue once they have all completed.  This allows you to spread their execution across multiple processes or even servers (depending upon how your job queue processes are configured).

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

#### Delays and Timeouts
When you run an operation in the background, it schedules an [ActiveJob](app/jobs/operations/task_runner_job.rb) which performs the individual state handler, scheduling a follow-up job for subsequent states.  By default, these jobs are scheduled to run after 1 second - so a five state operation will take a minimum of five seconds to complete (depending upon the backlog in your job queues).  This is to prevent a single operation from starving the job process of resources and allow other ActiveJobs the time to execute.  

However, if you know that your `wait_until` condition may take a while you can change the default delay to something longer.  In your operations definition, declare the required delay: 

```ruby
class ParallelTasks < Operations::Tasks 
  delay 1.minute
  ...
end
```

Likewise, it's possible for a background task to get stuck.  In the sub-tasks example above, if one of the sub-tasks fails, waiting for them _all_ to complete will never happen.  Every operation has a default timeout of 5 minutes - if the operation has not completed or failed 5 minutes after it was initially started, it will fail with an `Operations::Timeout` exception.  

If you need to change this (such as the user verification example above), you can declare the timeout when defining the operation.  Long timeouts fit well with longer delays, so you're not filling the job queues with jobs that are meaninglessly evaluating your conditions.

```ruby
class UserRegistration < Operations::Task 
  timeout 24.hours 
  delay 15.minutes
  ...
end
```

Instead of failing with an `Operations::Timeout` exception, you define an `on_timeout` handler for any special processing should the time-out occur.  

```ruby 
class WaitForSomething < Operations::Task 
  timeout 10.minutes 
  delay 1.minute 

  on_timeout do 
    Notifier.send_timeout_notification
  end
end
```

#### Zombie tasks

There's a chance that the `Operations::TaskRunnerJob` might get lost - maybe there's a crash in some process and the job does not restart correctly.  As the process for handling background tasks relies on the task "waking up", performing the next action, then queuing up the next task-runner, if the background job does not queue as expected, the task will sit there, waiting forever.  

To monitor for this, every task can be checked to see if it is a `zombie?`.  This means that the current time is more than 3 times the expected delay, compared to the `updated_at` field.  So if the `delay` is set to 1 minute and the task last woke up more than 3 minutes ago, it is classed as a zombie.  

There are two ways to handle zombies.  
- Manually; add a user interface listing your tasks with a "Restart" button.  The "Restart" button calls `restart` on the task (which internally schedules a new task runner job).
- Automatically; set up a cron job which calls the `operations:restart_zombie_tasks` rake task.  This rake task searches for zombie jobs and calls `restart` on them.  Note that cron jobs have a minimum resolution of 1 minute so this will cause pauses in tasks with a delay measured in seconds.   Also be aware that a cron job that calls a rake task will load the entire Rails stack as a new process, so be sure that your server has sufficient memory to cope.  If you're using [SolidQueue](https://github.com/rails/solid_queue/), the job runner already sets up a separate "supervisor" process and allows you to define [recurring jobs](https://github.com/rails/solid_queue/#recurring-tasks) with a resolution of 1 second.  This may be a suitable solution, but I've not tried it yet.  


### Waiting
Wait handlers are very similar to decision handlers but only work within [background tasks](#background-operations-and-pauses).  

```ruby 
wait_until :weather_forecast_available? do 
  condition { weather_forecast.sunny? }
  go_to :the_beach 
  condition { weather_forecast.rainy? }
  go_to :grab_an_umbrella 
  condition { weather_forecast.snowing? }
  go_to :build_a_snowman 
end
```

If no conditions are met, then, unlike a decision handler, the task continues waiting in the same state.  

