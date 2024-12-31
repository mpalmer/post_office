require 'logger'
require 'socket'
require 'thread'

module PostOffice
  # This class starts a generic server, accepting connections
  # on options[:port]
  #
  # When extending this class make sure you:
  #
  # * def greet(client)
  # * def process(client, command, full_data)
  # * client.close when you're done
  #
  # You can respond to the client using:
  #
  # * respond(client, text)
  #
  # The command given to process equals the first word
  # of full_data in upcase, e.g. QUIT or LIST
  #
  # It's possible for multiple clients to connect at the same
  # time, so use client.object_id when storing local data

  class GenericServer
    attr_reader :port

    def initialize(options)
      port = options[:port]
      @logger = options[:logger] || Logger.new("/dev/null")
      @server = TCPServer.open(port)
      @port = @server.addr[1]

      @logger.info "#{self.class.to_s} listening on port #{@port}"

      # Try to increase the buffer to give us some more time to parse incoming data
      begin
        @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVBUF, 1024 * 1024)
      rescue
        # then try it using our available buffer
      end
    end

    def run
      # Accept connections until infinity and beyond
      loop do
        Thread.start(@server.accept) do |client|
          begin
            client_addr = client.addr
            @logger.info "#{self.class.to_s} accepted connection #{client.object_id} from #{client_addr.inspect}"
            greet client

            # Keep processing commands until somebody closed the connection
            begin
              input = client.gets

              # The first word of a line should contain the command
              command = input.to_s.gsub(/ .*/,"").upcase.gsub(/[\r\n]/,"")

              @logger.debug "#{client.object_id}:#{@port} < #{input}"

              process(client, command, input)

            end until client.closed?
            @logger.info "#{self.class.to_s} closed connection #{client.object_id} with #{client_addr.inspect}"
          rescue => detail
            @logger.error "#{client.object_id}:#{@port} ! #{$!}"
            client.close
          end
        end
      end
    end

    # Respond to client by sending back text
    def respond(client, text)
      @logger.debug "#{client.object_id}:#{@port} > #{text}"
      client.write text
    rescue
      @logger.error "#{client.object_id}:#{@port} ! #{$!}"
      client.close
    end
  end
end
