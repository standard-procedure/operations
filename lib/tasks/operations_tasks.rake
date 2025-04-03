desc "Restart any zombie tasks"
task :restart_zombie_tasks do
  Operations::Task.restart_zombie_tasks
end
