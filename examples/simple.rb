$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))
require 'stapfen'


class Worker < Stapfen::Worker

  configure do
    {:hosts => [
      {
        :host => 'localhost',
        :port => 61613,
        :login => 'guest',
        :passcode => 'guest',
        :ssl => false
      }
    ]}
  end

  consume 'jms.queue.test' do |message|
    puts "received: #{message}"
  end

  consume 'jms.topic.foo', {:ack => 'client'} do |message|
    client.acknowledge(message)
  end
end


Worker.run!
