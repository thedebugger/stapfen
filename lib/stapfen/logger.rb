
module Stapfen
  # Logging module to ensure that {{Stapfen::Worker}} classes can perform
  # logging if they've been configured to
  module Logger
    # Collection of methods to pass arguments through from the class and
    # instance level to a configured logger
    PROXY_METHODS = [:info, :debug, :warn, :error].freeze

    module ClassMethods
      PROXY_METHODS.each do |method|
        define_method(method) do |*args|
          proxy_log_method(method, args)
        end
      end

      private

      def proxy_log_method(method, arguments)
        if self.logger
          self.logger.send(method, *arguments)
          return true
        end
        return false
      end
    end

    def self.included(klass)
      klass.extend(ClassMethods)
    end

    PROXY_METHODS.each do |method|
      define_method(method) do |*args|
        proxy_log_method(method, args)
      end
    end

    private

    def proxy_log_method(method, arguments)
      if self.class.logger
        self.class.logger.send(method, *arguments)
        return true
      end
      return false
    end
  end
end
