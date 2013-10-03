require 'spec_helper'

if RUBY_PLATFORM == 'java'
  require 'stapfen/client/jms'

  describe Stapfen::Client::JMS, :java => true do
    let(:config) { {} }
    subject(:client) { described_class.new(config) }

    it { should respond_to :connect }

    describe '#can_unreceive?' do
      subject { client.can_unreceive? }

      it { should_not be_true }
    end
  end
end
