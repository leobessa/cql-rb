# encoding: utf-8

require 'spec_helper'
require 'socket'


class Connection
  def self.open(host, port)
    new(TCPSocket.new(host, port))
  end

  def initialize(socket)
    @socket = socket
  end

  def close
    @socket.close
  end

  def send(request)
    frame = Cql::RequestFrame.new(request)
    frame.write(@socket)
    @socket.flush
    receive
  end

  def receive
    frame = Cql::ResponseFrame.new
    until frame.complete?
      frame << @socket.read(frame.length ? frame.length : 8)
    end
    frame.body
  end
end

describe 'Startup' do
  let :connection do
    Connection.open('localhost', 9042)
  end

  after do
    connection.close
  end

  it 'sends OPTIONS and receives SUPPORTED' do
    response = connection.send(Cql::OptionsRequest.new)
    response.options.should include('CQL_VERSION' => ['3.0.0'])
  end

  it 'sends STARTUP and receives READY' do
    response = connection.send(Cql::StartupRequest.new)
    response.should be_ready
  end

  it 'sends a bad STARTUP and receives ERROR' do
    response = connection.send(Cql::StartupRequest.new('9.9.9'))
    response.should be_error
    response.code.should == 10
    response.message.should include('not supported')
  end

  it 'sends a REGISTER request and receives READY' do
    connection.send(Cql::StartupRequest.new)
    response = connection.send(Cql::RegisterRequest.new('TOPOLOGY_CHANGE', 'STATUS_CHANGE', 'SCHEMA_CHANGE'))
    response.should be_ready
  end
end