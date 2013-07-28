require 'stomp'
require 'stapfen/logger'

module Stapfen
  class Worker
    include Stapfen::Logger

    class << self
      attr_accessor :configuration, :consumers, :logger
    end

    # Instantiate a new +Worker+ instance and run it
    def self.run!
      self.new.run
    end

    # Expects a block to be passed which will yield the appropriate
    # configuration for the Stomp gem. Whatever the block yields will be passed
    # directly into the {{Stomp::Client#new}} method
    def self.configure
      unless block_given?
        raise Stapfen::ConfigurationError
      end
      @configuration = yield
    end

    # Optional method, should be passed a block which will yield a {{Logger}}
    # instance for the Stapfen worker to use
    def self.log
      @logger = yield
    end


    # Main message consumption block
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
      @client = Stomp::Client.new(self.class.configuration)

      self.class.consumers.each do |name, headers, block|

        # We're taking each block and turning it into a method so that we can
        # use the instance scope instead of the blocks originally bound scope
        # which would be at a class level
        method_name = name.gsub(/[.|\-]/, '_').to_sym
        self.class.send(:define_method, method_name, &block)

        client.subscribe(name, headers) do |message|
          self.send(method_name, message)
        end
      end

      begin
        # Performing this join/open loop to make sure that we don't
        # experience potential deadlocks between signal handlers who might
        # close the connection, and an infinite Client#join call
        while client.open? do
          client.join(1)
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
      unless client.closed?
        client.close
      end
    end
  end
end
