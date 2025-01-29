require_relative "lib/operations/version"

Gem::Specification.new do |spec|
  spec.name = "standard_procedure_operations"
  spec.version = Operations::VERSION
  spec.authors = ["Rahoul Baruah"]
  spec.email = ["rahoulb@echodek.co"]
  spec.homepage = "https://theartandscienceofruby.com/"
  spec.summary = "Operations"
  spec.description = "Pipelines and State Machines for composable, trackable business logic"
  spec.license = "LGPL"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/standard-procedure/operations"
  spec.metadata["changelog_uri"] = "https://github.com/standard-procedure/operations/releases"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.1.3"
end
