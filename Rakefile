require 'rake/clean'
require 'rspec/core/rake_task'
require 'rubygems'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = [ "--backtrace",
                   '--format progress',
                   "--fail-fast",
                   '--color',
                   '--tag', '~disabled']
end

task :default => :spec
