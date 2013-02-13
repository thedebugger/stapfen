require 'stomp'

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
      @pool = []
      @workqueue = Queue.new
      handle_signals!
    end

    def main_thread(&block)
      @workqueue << block
    end

    def run
      @client = Stomp::Client.new(self.class.configuration)

      self.class.consumers.each do |name, headers, block|
        client.subscribe(name, headers) do |message|
          @pool << Thread.new do
            block.call(message)
          end
        end
      end

      begin
        # Performing this join/open loop to make sure that we don't
        # experience potential deadlocks between signal handlers who might
        # close the connection, and an infinite Client#join call
        while client.open? do
          client.join(1)

          until @workqueue.empty?
            block = @workqueue.pop
            begin
              block.call
            rescue => e
              puts "Exception! #{e}"
            end
          end

          @pool = @pool.select { |t| t.alive? }
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
      unless @pool.empty?
        puts "Giving #{@pool.size} threads 10s each to finish up"
        @pool.each do |t|
          t.join(10)
        end
      end
      unless client.closed?
        client.close
      end
    end
  end
end
