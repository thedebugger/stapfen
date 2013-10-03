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

    describe '#use_stomp!' do
      subject(:result) { worker.use_stomp! }

      it 'should update the instance variable' do
        expect(result).to be_true
        expect(worker).to be_stomp
        expect(worker).not_to be_jms
      end
    end

    describe '#use_jms!', :java => true do
      subject(:result) { worker.use_jms! }

      after :each do
        # Reset to the default since we've modified the class
        worker.use_stomp!
      end

      it 'should update the instance variable' do
        expect(result).to be_true
        expect(worker).to be_jms
        expect(worker).not_to be_stomp
      end
    end

    describe '#log' do
      it "should store the block it's passed" do
        logger = double('Mock Logger')

        worker.log do
          logger
        end

        expect(worker.logger).to be_instance_of Proc
      end

      after :each do
        worker.logger = nil
      end
    end

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

        expect(worker.configuration.call).to eql(config)
      end
    end

    describe '#exit_cleanly' do
      subject(:result) { worker.exit_cleanly }

      context 'with no worker classes' do
        it { should be_false }
      end

      context 'with a single worker class' do
        let(:w) { double('Fake worker instance') }

        before :each do
          worker.class_variable_set(:@@workers, [w])
        end

        it "should execute the worker's #exit_cleanly method" do
          w.should_receive(:exit_cleanly)
          expect(result).to be_true
        end

        it "should return false if the worker's #exit_cleanly method" do
          w.should_receive(:exit_cleanly).and_raise(StandardError)
          expect(result).to be_false
        end
      end

      context 'with multiple worker classes' do
        let(:w1) { double('Fake Worker 1') }
        let(:w2) { double('Fake Worker 2') }

        before :each do
          worker.class_variable_set(:@@workers, [w1, w2])
        end

        it 'should invoke both #exit_cleanly methods' do
          w1.should_receive(:exit_cleanly)
          w2.should_receive(:exit_cleanly)
          expect(result).to be_true
        end
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
        let(:client) do
          c = double('Mock Stapfen::Client')
          c.stub(:connect)
          c.stub(:can_unreceive? => true)
          c.stub(:runloop)
          c
        end

        let(:name) { '/queue/some_queue' }
        let(:message) do
          m = Stomp::Message.new(nil)
          m.stub(:body => 'rspec msg')
          m
        end


        before :each do
          Stapfen::Client::Stomp.stub(:new).and_return(client)

          # Get a subscription?  Call the message handler block.
          client.stub(:subscribe) do |name, headers, &block|
            block.call(message)
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
              client.should_receive(:unreceive).with(message, unrec_headers).once

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

      context 'with out having connected a client yet' do
        before :each do
          worker.stub(:client).and_return(nil)
        end

        it 'should not raise any errors' do
          expect {
            worker.exit_cleanly
          }.not_to raise_error
        end
      end
    end
  end
end
