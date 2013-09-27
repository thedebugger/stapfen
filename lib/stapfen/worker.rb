require 'stomp'
require 'stapfen/logger'
require 'stapfen/destination'
require 'stapfen/message'

module Stapfen
  class Worker
    include Stapfen::Logger

    # Class variables!
    @@signals_handled = false
    @@workers = []

    # Class instance variables!
    @use_stomp = true

    class << self
      attr_accessor :configuration, :consumers, :logger, :destructor

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

    # Force the worker to use STOMP as the messaging protocol (default)
    #
    # @return [Boolean]
    def self.use_stomp!
      begin
        require 'stomp'
      rescue LoadError
        puts "You need the `stomp` gem to be installed to use stomp!"
        raise
      end

      @use_stomp = true
      return true
    end

    def self.stomp?
      @use_stomp
    end

    # Force the worker to use JMS as the messaging protocol.
    #
    # *Note:* Only works under JRuby
    #
    # @return [Boolean]
    def self.use_jms!
      unless RUBY_PLATFORM == 'java'
        raise Stapfen::ConfigurationError, "You cannot use JMS unless you're running under JRuby!"
      end

      begin
        require 'java'
        require 'jms'
      rescue LoadError
        puts "You need the `jms` gem to be installed to use JMS!"
        raise
      end

      @use_stomp = false
      return true
    end

    def self.jms?
      !(@use_stomp)
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

    # Invoke +exit_cleanly+ on each of the registered Worker instances that
    # this class is keeping track of
    #
    # @return [Boolean] Whether or not we've exited/terminated cleanly
    def self.exit_cleanly
      return false if workers.empty?

      cleanly = true
      workers.each do |w|
        begin
          w.exit_cleanly
        rescue StandardError => ex
          $stderr.write("Failure while exiting cleanly #{ex.inspect}\n#{ex.backtrace}")
          cleanly = false
        end
      end

      return cleanly
    end

    # Utility method to set up the proper worker signal handlers
    def self.handle_signals
      return if @@signals_handled

      Signal.trap(:INT) do
        self.exit_cleanly
        exit!
      end

      Signal.trap(:TERM) do
        self.exit_cleanly
      end

      @@signals_handled = true
    end



    ############################################################################
    # Instance Methods
    ############################################################################

    attr_accessor :client

    def run
      if self.class.stomp?
        run_stomp
      elsif self.class.jms?
        run_jms
      end
    end

    def run_jms
      JMS::Connection.start(self.class.configuration.call) do |connection|
        @client = connection
        debug("Running with #{@client} inside of Thread:#{Thread.current.inspect}")

        self.class.consumers.each do |name, headers, block|
          destination = Stapfen::Destination.from_string(name)
          type = 'queue'
          options = {}

          if destination.queue?
            options[:queue_name] = destination.name
          end

          if destination.topic?
            type = 'topic'
            options[:topic_name] = destination.name
          end

          method_name = "handle_#{type}_#{name}".to_sym
          self.class.send(:define_method, method_name, &block)

          connection.on_message(options) do |m|
            message = Stapfen::Message.from_jms(m)
            self.send(method_name, message)
          end
        end

        begin
          loop do
            sleep 1
          end
          debug("Exiting the JMS runloop for #{self}")
        rescue Interrupt
          exit_cleanly
        end
      end
    end

    def run_stomp
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
