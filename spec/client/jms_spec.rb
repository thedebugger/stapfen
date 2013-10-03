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

    describe '#connect' do
      subject(:connection) { client.connect }
      let(:jms_conn) { double('JMS::Connection') }

      before :each do
        ::JMS::Connection.should_receive(:new).and_return(jms_conn)
      end

      it 'should start the connection' do
        jms_conn.should_receive(:start)
        expect(connection).to eql(jms_conn)
      end
    end

    describe '#session' do
      let(:session) { double('JMS::Session') }
      let(:connection) { double('JMS::Connection') }

      before :each do
        client.stub(:connection => connection)
      end

      context 'without a session already' do
        it 'should create a new session' do
          connection.should_receive(:create_session).and_return(session)
          expect(client.session).to eql(session)
        end
      end

      context 'with an existing session' do
        it 'should return that existing session' do
          connection.should_receive(:create_session).once.and_return(session)
          3.times do
            expect(client.session).to eql(session)
          end
        end
      end
    end

    describe '#publish' do
    end

    describe '#close' do
      subject(:result) { client.close }
      let(:connection) { double('JMS::Connection') }

      before :each do
        client.instance_variable_set(:@connection, connection)
      end

      context 'without an existing session' do
        it 'should close the client' do
          connection.should_receive(:close)
          expect(result).to be_true
        end
      end

      context 'with an existing session' do
        let(:session) { double('JMS::Session') }

        before :each do
          client.instance_variable_set(:@session, session)
        end

        it 'should close the client and session' do
          session.should_receive(:close)
          connection.should_receive(:close)
          expect(result).to be_true
        end
      end
    end
  end
end
