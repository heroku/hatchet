require 'rake'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/hatchet/**/*_test.rb'
  t.verbose = false
end

