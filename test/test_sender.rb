require File.expand_path '../minitest_helper.rb', __FILE__

require 'mocha'
require 'multi_json'

class FakeSocket
  def initialize host = nil, port = nil
  end
  def write message
    # puts "FAKE TCPSocket#write #{message.inspect}";
    message
  end
end

describe Logvoyage do
  before do
    @fake_socket = FakeSocket.new
  end

  describe Logvoyage::TcpSender do
    it "send" do
      TCPSocket.expects(:new).returns(@fake_socket)
      sender = Logvoyage::TcpSender.new host: 'localhost', api_key: 'SOMEKEY'
      res = sender.send(0, MultiJson.dump({message: 'Hi world', user_id: 123}))
      res = res.split(" ")
      header, json = res[0], res[1..-1].join(' ')

      header.must_equal 'SOMEKEY@debug'
      body = MultiJson.load json

      body["message"].must_equal "Hi world"
      body["user_id"].must_equal 123
    end
  end

end
