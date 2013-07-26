require 'thread'
require 'onstomp'

module Stapfen
  class Worker
    class << self
      attr_accessor :configuration, :consumers
    end

    def self.run!
      self.new.run
    end

    def self.configure
      unless block_given?
        raise Stapfen::ConfigurationError
      end
      @configuration = yield
    end

    def self.consume(queue_name, headers={}, &block)
      unless block_given?
        raise Stapfen::ConsumeError, "Cannot consume #{queue_name} without a block!"
      end
      @consumers ||= []
      @consumers << [queue_name, headers, block]
    end

    attr_accessor :client

    def initialize
      handle_signals!
    end


    def run
      @client = OnStomp::Client.new(generate_uri)
      @client.connect

      self.class.consumers.each do |name, headers, block|
        # We're taking each block and turning it into a method so that we can
        # use the instance scope instead of the blocks originally bound scope
        # which would be at a class level
        method_name = name.gsub(/[.|\-]/, '_').to_sym
        self.class.send(:define_method, method_name, &block)

        client.subscribe(name, headers) do |message|
          puts "invoking #{method_name} for #{message.inspect}"
          self.send(method_name, message)
        end
      end

      begin
        # Performing this join/open loop to make sure that we don't
        # experience potential deadlocks between signal handlers who might
        # close the connection, and an infinite Client#join call
        while client.connected? do
          sleep(0.2)
        end
      rescue Interrupt
        exit_cleanly
      end
    end

    def handle_signals!
      Signal.trap(:INT) do
        exit_cleanly
        exit!
      end
      Signal.trap(:TERM) do
        exit_cleanly
      end
    end

    def exit_cleanly
      if client.connected?
        client.disconnect
      end
    end

    # Convert Stapfen configuration into an OnStomp URL
    #
    # @return [String]
    def generate_uri
      config = self.class.configuration
      raise Stapfen::ConfigurationError if config.nil? || config.empty?

      user_info = nil

      if config[:login] && config[:passcode]
        user_info = "#{config[:login]}:#{config[:passcode]}@"
      end

      "stomp://#{user_info}#{config[:host]}:#{config[:port]}"
    end
  end
end
