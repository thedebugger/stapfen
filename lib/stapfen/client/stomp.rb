require 'stomp'

module Stapfen
  module Client
    class Stomp < ::Stomp::Client
      def connect(*args)
        # No-op, since Stomp::Client will connect on instantiation
      end

      def can_unreceive?
        true
      end

      def runloop
        # Performing this join/runningloop to make sure that we don't
        # experience potential deadlocks between signal handlers who might
        # close the connection, and an infinite Client#join call
        #
        # Instead of using client#open? we use #running which will still be
        # true even if the client is currently in an exponential reconnect loop
        while self.running do
          self.join(1)
        end
      end
    end
  end
end
