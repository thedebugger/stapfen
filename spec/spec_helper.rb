$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '../lib'))

require 'stapfen'


is_java = (RUBY_PLATFORM == 'java')

unless is_java
  require 'debugger'
  require 'debugger/pry'
end


RSpec.configure do |c|
  unless is_java
    c.filter_run_excluding :java => true
  end
end
