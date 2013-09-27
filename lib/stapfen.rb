require 'stapfen/version'
require 'stapfen/worker'

module Stapfen
  class ConfigurationError < StandardError
  end
  class ConsumeError < StandardError
  end
  class InvalidMessageError < StandardError
  end
end
