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

        worker.configuration.call.should == config
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
          worker.consume(name) do |msg|
            nil
          end

          worker.consumers.should_not be_empty
          entry = worker.consumers.first
          entry.first.should eq(name)
        end
      end

      context 'unreceive behavior' do
        let(:client) { mock('Stomp::Client', :open? => false) }
        let(:name) { '/queue/some_queue' }
        before :each do
          Stomp::Client.stub(:new).and_return(client)

          # Get a subscription?  Call the message handler block.
          client.stub(:subscribe) do |name, headers, &block|
            block.call('msg')
          end
        end

        context 'with just a queue name' do
          context 'on a failed message' do
            it 'should not unreceive' do
              client.should_receive(:unreceive).never

              worker.consume(name) {|msg| false }
              worker.new.run
            end
          end
          context 'on a successful message' do
            it 'should not unreceive' do
              client.should_receive(:unreceive).never

              worker.consume(name) {|msg| true }
              worker.new.run
            end
          end
        end

        context 'with a queue name and headers for a dead_letter_queue and max_redeliveries' do
          let(:unrec_headers) do
            { :dead_letter_queue => '/queue/foo',
            :max_redeliveries => 3 }
          end
          let(:raw_headers) { unrec_headers.merge(:other_header => 'foo!') }
          context 'on a failed message' do
            it 'should unreceive' do
              client.should_receive(:unreceive).once

              worker.consume(name, raw_headers) {|msg| false }
              worker.new.run
            end
            it 'should pass :unreceive_headers through to the unreceive call' do
              client.should_receive(:unreceive).with('msg', unrec_headers).once

              worker.consume(name, raw_headers) {|msg| false }
              worker.new.run
            end
          end
          context 'on a successfully handled message' do
            it 'should not unreceive' do
              client.should_receive(:unreceive).never

              worker.consume(name, raw_headers) {|msg| true }
              worker.new.run
            end
          end
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
