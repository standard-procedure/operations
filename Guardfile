group :development do
  guard :rspec, cmd: "bundle exec rspec" do
    watch(%r{^spec/.+_spec.rb$})
    watch(%r{^lib/(.+).rb$}) { "spec" }
    watch(%r{^app/(.+).rb$}) { "spec" }
  end

  guard :bundler do
    require "guard/bundler"
    require "guard/bundler/verify"
    helper = Guard::Bundler::Verify.new

    files = ["Gemfile"]
    files += Dir["*.gemspec"] if files.any? { |f| helper.uses_gemspec?(f) }

    # Assume files are symlinked from somewhere
    files.each { |file| watch(helper.real_path(file)) }
  end
end

guard :standardrb, fix: true, all_on_start: true, progress: true do
  watch(/.+.rb$/)
end
