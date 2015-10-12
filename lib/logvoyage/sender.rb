module Logvoyage

  class BaseSender
    def initialize host: 'localhost', port: 27078, api_key: nil
      @host, @port, @api_key = host, port, api_key
    end
    def send level, message
    end
  end

  class TcpSender < BaseSender
    def send level, message
      message = "#{@api_key}@#{LOGTYPES_MAPPING[level]} #{message}\n"
      # puts "TcpSender#send #{message.inspect}"
      socket.write message
    end

    def socket
      @socket ||= TCPSocket.new @host, @port
    end

    def close
      @socket.close if @socket
    end
  end


  # TODO
  class HttpSender < BaseSender
    def send messages
      raise "TODO"


      uri = URI.parse("http://#{host}:#{port}/bulk?apiKey=#{@api_key}&type=#{type}")

      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = post_body.join
      request["Content-Type"] = "multipart/form-data, boundary=#{BOUNDARY}"

      http.request(request)


      Net::HTTP.post



      # curl -d @- http://localhost:27078/bulk\?apiKey\=API_KEY\&type\=LOG_TYPE
      # messages.each {|packet| @socket.write packet}
    end

    def close
      @socket.close
    end
  end
end
