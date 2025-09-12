desc "Start the Task Runner process"
task :agent_runner do
  Operations::Task::Runner.start
end
