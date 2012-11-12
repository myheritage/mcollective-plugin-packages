require 'rake/clean'
require 'rspec/core/rake_task'
require 'rubygems'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = [ "--backtrace",
                   '--format progress',
                   "--fail-fast",
                   '--color' ]
  t.rspec_path = "rspec1.9.1"
end

task :default => :spec
