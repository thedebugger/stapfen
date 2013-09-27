require 'spec_helper'
require 'stapfen/message'

if RUBY_PLATFORM == 'java'
  require 'java'
  require File.expand_path('./activemq-all-5.8.0.jar')
end

describe Stapfen::Message do
  context 'accessors' do
    it { should respond_to :message_id }
    it { should respond_to :body }
    it { should respond_to :original }
    it { should respond_to :destination }
  end

  describe '#initialize' do
    it 'should accept :body' do
      body = 'hello'
      m = described_class.new(:body => body)
      expect(m.body).to eql(body)
    end
  end

  context 'class methods' do
    let(:body) { 'hello stapfen' }
    let(:destination) { '/queue/rspec' }
    let(:message_id) { rand.to_s }

    describe '#from_stomp' do
      subject(:result) { described_class.from_stomp(message) }

      context 'when passed something other than a Stomp::Message' do
        let(:message) { 'hello' }

        it 'should raise an error' do
          expect { result }.to raise_error(Stapfen::InvalidMessageError)
        end
      end

      context 'when passed a Stomp::Message' do
        let(:message) do
          m = Stomp::Message.new('') # empty frame
          m.body = body
          headers = {'destination' => destination,
                     'message-id' => message_id}
          m.headers = headers
          m
        end

        it 'should create an instance' do
          expect(result).to be_instance_of Stapfen::Message
        end

        its(:body) { should eql body }
        its(:destination) { should eql destination }
        its(:message_id) { should eql message_id }
        its(:original) { should be message }
      end
    end

    describe '#from_jms', :java => true do
      subject(:result) { described_class.from_jms(message) }

      context 'when passed something other than a JMS message' do
        let(:message) { 'hello' }

        it 'should raise an error' do
          expect { result }.to raise_error(Stapfen::InvalidMessageError)
        end
      end

      context 'when passed an ActiveMQBytesMessage' do
        let(:destination) { 'queue://rspec' }

        let(:message) do
          m = Java::OrgApacheActivemqCommand::ActiveMQBytesMessage.new
          m.stub(:jms_destination => double('ActiveMQDestination mock', :getQualifiedName => destination))
          m.stub(:jms_message_id => message_id)
          m.stub(:data => body)
          m
        end

        it 'should create an instance' do
          expect(result).to be_instance_of Stapfen::Message
        end

        its(:body) { should eql body }
        its(:destination) { should eql destination }
        its(:message_id) { should eql message_id }
        its(:original) { should be message }

      end
    end
  end
end
