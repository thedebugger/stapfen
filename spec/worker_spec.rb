require 'spec_helper'


describe Stapfen::Worker do
  subject(:worker) { described_class.new }

  context 'class methods' do
    subject(:worker) { described_class }

    it { should respond_to :run! }
    it { should respond_to :configure }
    it { should respond_to :consume }
    it { should respond_to :log }
    it { should respond_to :shutdown }

    describe '#configure' do
      it 'should error when not passed a block' do
        expect {
          worker.configure
        }.to raise_error(Stapfen::ConfigurationError)
      end

      it 'should save the return value from the block' do
        config = {:valid => true}

        worker.configure do
          config
        end

        worker.configuration.should == config
      end
    end


    describe 'consume' do
      it 'should raise an error if no block is passed' do
        expect {
          worker.consume 'jms.queue.lol'
        }.to raise_error(Stapfen::ConsumeError)
      end

      context 'with just a queue name' do
        let(:name) { 'jms.queue.lol' }

        it 'should add an entry for the queue name' do
          worker.consume(name)  do
            nil
          end

          worker.consumers.should_not be_empty
          entry = worker.consumers.first
          entry.first.should eq(name)
        end
      end
    end
  end

  context 'instance methods' do
    describe '#exit_cleanly' do
      let(:client) { double('RSpec Stomp Client') }

      before :each do
        worker.stub(:client).and_return(client)
      end

      it 'should close the client' do
        client.stub(:closed?).and_return(false)
        client.should_receive(:close)
        worker.exit_cleanly
      end
    end
  end
end
