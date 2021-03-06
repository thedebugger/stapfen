require 'jms'
require 'stapfen/destination'

module Stapfen
  module Client
    class JMS
      attr_reader :connection

      def initialize(configuration)
        super()
        @config = configuration
        @connection = nil
      end

      # Connect to the broker via JMS and start the JMS session
      #
      # @return [JMS::Connection]
      def connect(*args)
        @connection = ::JMS::Connection.new(@config)
        @connection.start
        return @connection
      end

      # Accessor method which will cache the session if we've already created
      # it once
      #
      # @return [JMS::Session] Instantiated +JMS::Session+ for our
      #   +connection+
      def session
        @session ||= connection.create_session
      end

      def publish(destination, body, headers={})
        destination = Stapfen::Destination.from_string(destination)

        session.producer(destination.jms_opts) do |p|
          # Create the JMS typed Message
          message = session.message(body)

          message.delivery_mode = ::JMS::DeliveryMode::PERSISTENT if headers.delete(:persistent)

          # Take the remainder of the headers and push them into the message
          # properties.
          headers.each_pair do |key, value|
            message.setStringProperty(key.to_s, value.to_s)
          end

          p.send(message)
        end
      end

      def subscribe(destination, headers={}, &block)
        destination = Stapfen::Destination.from_string(destination)
        connection.on_message(destination.jms_opts) do |m|
          block.call(m)
        end
      end

      # Close the JMS::Connection and the JMS::Session if it's been created
      # for this client
      #
      # @return [Boolean] True/false depending on whether we actually closed
      #   the connection
      def close
        return false unless @connection
        @session.close if @session
        @connection.close
        @connection = nil
        return true
      end

      # API compatibilty method, doesn't actually indicate that the connection
      # is closed. Will only return true if no connection currently exists
      #
      # @return [Boolean]
      def closed?
        return connection.nil?
      end

      def runloop
        loop do
          sleep 1
        end
      end

      def can_unreceive?
        false
      end
    end
  end
end
