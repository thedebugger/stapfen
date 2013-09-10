require 'stomp'
require 'stapfen/logger'

module Stapfen
  class Worker
    include Stapfen::Logger

    @@signals_handled = false
    @@workers = []

    class << self
      attr_accessor :configuration, :consumers, :logger, :destructor
      attr_accessor :workers
    end

    # Instantiate a new +Worker+ instance and run it
    def self.run!
      worker = self.new

      @@workers << worker

      handle_signals

      worker.run
    end

    # Expects a block to be passed which will yield the appropriate
    # configuration for the Stomp gem. Whatever the block yields will be passed
    # directly into the {{Stomp::Client#new}} method
    def self.configure(&block)
      unless block_given?
        raise Stapfen::ConfigurationError
      end
      @configuration = block
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

    # Optional method, specifes a block to execute when the worker is shutting
    # down.
    def self.shutdown(&block)
      @destructor = block
    end

    # Return all the currently running Stapfen::Worker instances in this
    # process
    def self.workers
      @@workers
    end

    # Utility method to set up the proper worker signal handlers
    def self.handle_signals
      return if @@signals_handled

      Signal.trap(:INT) do
        @@workers.each do |w|
          w.exit_cleanly
        end
        exit!
      end
      Signal.trap(:TERM) do
        @@workers.each do |w|
          w.exit_cleanly
        end
      end

      @@signals_handled = true
    end



    ############################################################################
    # Instance Methods
    ############################################################################

    attr_accessor :client

    def run
      @client = Stomp::Client.new(self.class.configuration.call)
      debug("Running with #{@client} inside of Thread:#{Thread.current.inspect}")

      self.class.consumers.each do |name, headers, block|
        unreceive_headers = {}
        [:max_redeliveries, :dead_letter_queue].each do |sym|
          unreceive_headers[sym] = headers.delete(sym) if headers.has_key? sym
        end

        # We're taking each block and turning it into a method so that we can
        # use the instance scope instead of the blocks originally bound scope
        # which would be at a class level
        method_name = name.gsub(/[.|\-]/, '_').to_sym
        self.class.send(:define_method, method_name, &block)

        client.subscribe(name, headers) do |message|
          success = self.send(method_name, message)

          if !success && !unreceive_headers.empty?
            client.unreceive(message, unreceive_headers)
          end
        end
      end

      begin
        # Performing this join/runningloop to make sure that we don't
        # experience potential deadlocks between signal handlers who might
        # close the connection, and an infinite Client#join call
        #
        # Instead of using client#open? we use #running which will still be
        # true even if the client is currently in an exponential reconnect loop
        while client.running do
          client.join(1)
        end
        warn("Exiting the runloop for #{self}")
      rescue Interrupt
        exit_cleanly
      end
    end

    # Invokes the shutdown block if it has been created, and closes the
    # {{Stomp::Client}} connection unless it has already been shut down
    def exit_cleanly
      info("#{self} exiting cleanly")
      self.class.destructor.call if self.class.destructor

      # Only close the client if we have one sitting around
      if client && !client.closed?
        client.close
      end
    end
  end
end
