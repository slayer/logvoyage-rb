module Logvoyage
  class << self
    attr_accessor :api_key
  end

  # LogVoyage notifier.
  class Notifier

    attr_accessor :enabled, :host, :port, :rescue_network_errors
    attr_reader :level, :default_options, :level_mapping

    # +type+ is a one of :tcp, :udp, :http
    # +host+ and +port+ are host/ip and port of LogVoyage server.
    # +api_key+ LogVoyage API KEY
    # +default_options+ is used in notify!
    def initialize(type: :tcp, host: 'localhost', port: 27077, api_key: nil, default_options: {})
      @enabled = true
      @collect_file_and_line = false

      self.host = host
      self.port = port
      self.level = Logvoyage::DEBUG
      self.rescue_network_errors = false
      api_key ||= Logvoyage.api_key

      self.default_options = default_options
      self.default_options['version'] = VERSION
      self.default_options['host'] ||= Socket.gethostname
      self.default_options['level'] ||= Logvoyage::UNKNOWN
      self.default_options['facility'] ||= 'logvoyage-rb'

      @sender = case type
                when :udp   then UdpSender.new host: host, port: port, api_key: api_key
                when :tcp   then TcpSender.new host: host, port: port, api_key: api_key
                when :http  then HttpSender.new host: host, port: port, api_key: api_key
                else raise "Unknown #{sender}"
                end
      self.level_mapping = :logger
    end

    # Get a receiver host.
    def host
      self.host
    end

    # Get a port of receiver.
    def port
      self.port
    end

    def level=(new_level)
      @level = if new_level.is_a?(Fixnum)
                 new_level
               else
                 Logvoyage.const_get(new_level.to_s.upcase)
               end
    end

    def default_options=(options)
      @default_options = self.class.stringify_keys(options)
    end

    # +mapping+ may be a hash, 'logger' (Logvoyage::LOGGER_MAPPING) or 'direct' (Logvoyage::DIRECT_MAPPING).
    # Default (compatible) value is 'logger'.
    def level_mapping=(mapping)
      case mapping.to_s.downcase
        when 'logger'
          @level_mapping = Logvoyage::LOGGER_MAPPING
        when 'direct'
          @level_mapping = Logvoyage::DIRECT_MAPPING
        else
          @level_mapping = mapping
      end
    end

    def disable
      @enabled = false
    end

    def enable
      @enabled = true
    end

    # Same as notify!, but rescues all exceptions (including +ArgumentError+)
    # and sends them instead.
    def notify(*args)
      notify_with_level(nil, *args)
    end

    # Sends message to LogVoyage server.
    # +args+ can be:
    # - hash-like object (any object which responds to +to_hash+, including +Hash+ instance):
    #    notify!(:message => 'All your rebase are belong to us', :user => 'AlekSi')
    # - exception with optional hash-like object:
    #    notify!(SecurityError.new('ALARM!'), :trespasser => 'AlekSi')
    # - string-like object (anything which responds to +to_s+) with optional hash-like object:
    #    notify!('Plain olde text message', :scribe => 'AlekSi')
    # Resulted fields are merged with +default_options+, the latter will never overwrite the former.
    # This method will raise +ArgumentError+ if arguments are wrong. Consider using notify instead.
    def notify!(*args)
      notify_with_level!(nil, *args)
    end

    Logvoyage::Levels.constants.each do |const|
      class_eval <<-EOT, __FILE__, __LINE__ + 1
        def #{const.downcase}(*args)                          # def debug(*args)
          notify_with_level(Logvoyage::#{const}, *args)            #   notify_with_level(Logvoyage::DEBUG, *args)
        end                                                   # end
      EOT
    end

  private
    def notify_with_level(message_level, *args)
      notify_with_level!(message_level, *args)
    rescue SocketError, SystemCallError
      raise unless self.rescue_network_errors
    rescue Exception => exception
      notify_with_level!(Logvoyage::UNKNOWN, exception)
    end

    def notify_with_level! message_level, *args
      return unless @enabled
      extract_hash(*args)
      @hash['level'] = message_level unless message_level.nil?
      if @hash['level'] >= level
        @sender.send message_level, serialize_hash
      end
    end

    def extract_hash(object = nil, args = {})
      primary_data = if object.respond_to?(:to_hash)
                       object.to_hash
                     elsif object.is_a?(Exception)
                       args['level'] ||= Logvoyage::ERROR
                       self.class.extract_hash_from_exception(object)
                     else
                       args['level'] ||= Logvoyage::INFO
                       { 'message' => object.to_s }
                     end

      @hash = default_options.merge(self.class.stringify_keys(args.merge(primary_data)))
      set_file_and_line if @collect_file_and_line
      set_timestamp
      check_presence_of_mandatory_attributes
      @hash
    end

    def self.extract_hash_from_exception(exception)
      bt = exception.backtrace || ["Backtrace is not available."]
      { 'message' => "#{exception.class}: #{exception.message}", 'full_message' => "Backtrace:\n" + bt.join("\n") }
    end

    CALLER_REGEXP = /^(.*):(\d+).*/
    LIB_Logvoyage_PATTERN = File.join('lib', 'gelf')

    def set_file_and_line
      stack = caller
      begin
        frame = stack.shift
      end while frame.include?(LIB_Logvoyage_PATTERN)
      match = CALLER_REGEXP.match(frame)
      @hash['file'] = match[1]
      @hash['line'] = match[2].to_i
    end

    def set_timestamp
      @hash['timestamp'] = Time.now.utc.to_i if @hash['timestamp'].nil?
    end

    def check_presence_of_mandatory_attributes
      %w(version message host).each do |attribute|
        if @hash[attribute].to_s.empty?
          raise ArgumentError.new("#{attribute} is missing. Options version, message and host must be set.")
        end
      end
    end

    def serialize_hash
      raise ArgumentError.new("Hash is empty.") if @hash.nil? || @hash.empty?

      @hash['level'] = @level_mapping[@hash['level']]
      MultiJson.dump @hash
    end

    def self.stringify_keys(hash)
      hash.keys.each do |key|
        value, key_s = hash.delete(key), key.to_s
        raise ArgumentError.new("Both #{key.inspect} and #{key_s} are present.") if hash.has_key?(key_s)
        hash[key_s] = value
      end
      hash
    end
  end
end
