require_relative "../../lib/operations/version"

Gem::Specification.new do |spec|
  spec.name = "operations-activejob"
  spec.version = Operations::VERSION
  spec.authors = ["Rahoul Baruah"]
  spec.email = ["rahoulb@echodek.co"]
  spec.homepage = "https://theartandscienceofruby.com/"
  spec.summary = "ActiveJob executor adapter for Operations"
  spec.description = "Provides ActiveJob-based background execution for Operations tasks"
  spec.license = "LGPL"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/standard-procedure/operations"
  spec.metadata["changelog_uri"] = "https://github.com/standard-procedure/operations/tags"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*", "README.md"]
  end

  spec.require_paths = ["lib"]

  # Depend on core gem with same major.minor version
  major_minor = Operations::VERSION.split('.')[0..1].join('.')
  spec.add_dependency "standard_procedure_operations", "~> #{major_minor}"
  spec.add_dependency "activejob", ">= 7.0"
end
