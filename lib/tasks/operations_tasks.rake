desc "Start the Agent Runner process"
task :agent_runner do
  Operations::Agent::Runner.start
end
