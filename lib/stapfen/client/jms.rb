require 'jms'
require 'stapfen/destination'

module Stapfen
  module Client
    class JMS
      def initialize(configuration)
        super()
        @config = configuration
        @connection = nil
      end

      def connect(*args)
        @connection = ::JMS::Connection.new(@config)
        @connection.start
        return @connection
      end

      def publish(destination, body, headers={})
        unless @session
          @session = @connection.create_session
        end

        destination = Stapfen::Destination.from_string(destination)

        @session.producer(destination.jms_opts) do |p|
          # Create the JMS typed Message
          message = @session.message(body)

          if headers[:persistent]
            headers.delete(:persistent)
            message.delivery_mode = ::JMS::DeliveryMode::PERSISTENT
          end

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
        @connection.on_message(destination.jms_opts) do |m|
          block.call(m)
        end
      end

      def close
        return unless @connection
        if @session
          @session.close
        end
        @connection.close
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
