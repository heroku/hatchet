# encoding: UTF-8
require 'bundler/gem_tasks'

require 'rake'
require 'rake/testtask'
require 'hatchet/tasks'

task :default => [:test]

test_task = Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/hatchet/**/*_test.rb'
  t.verbose = false
end
