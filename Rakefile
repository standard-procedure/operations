require "bundler/setup"

APP_RAKEFILE = File.expand_path("spec/test_app/Rakefile", __dir__)
load "rails/tasks/engine.rake"

load "rails/tasks/statistics.rake"

require "bundler/gem_tasks"
require "rspec/core"
require "rspec/core/rake_task"

desc "Run all specs in spec directory (excluding plugin specs)"
RSpec::Core::RakeTask.new(spec: "app:db:test:prepare")

task default: :spec
