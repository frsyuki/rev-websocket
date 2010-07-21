require 'rev'
require File.dirname(__FILE__)+'/websocket/spec'
require 'thin_parser'

module Rev
	class WebSocketServer < TCPServer
		def initialize(host, port = nil, klass = WebSocket, *args, &block)
			super
		end
	end

	# WebSocket spec:
	# http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-76

	class WebSocket < TCPSocket
		def on_open
		end

		def on_message(data)
		end

		def on_error(reason)
		end

		attr_reader :request

		def send_message(data)
			if HAVE_ENCODING
				frame = FRAME_START + data.force_encoding('UTF-8') + FRAME_END
			else
				frame = FRAME_START + data + FRAME_END
			end
			write frame
		end

		if "".respond_to?(:force_encoding)
			HAVE_ENCODING = true
			FRAME_START = "\x00".force_encoding('UTF-8')
			FRAME_END   = "\xFF".force_encoding('UTF-8')
		else
			HAVE_ENCODING = false
			FRAME_START = "\x00"
			FRAME_END   = "\xFF"
		end

		#HTTP11_PRASER = Mongrel::HttpParser
		HTTP11_PRASER = Thin::HttpParser

		# Thin::HttpParser tries to call request['rack.input'].write(body)
		class DummyIO
			KEY = 'rack.input'
			def write(data) end
		end

		def initialize(socket)
			super
			@state = :process_handshake
			@data = ::IO::Buffer.new
			@http11 = HTTP11_PRASER.new
			@http11_nbytes = 0
			@request = {DummyIO::KEY => DummyIO.new}
		end

		def on_readable
			super
		rescue
			close
		end

		def on_read(data)
			@data << data
			dispatch
		end

		protected

		def dispatch
			while __send__(@state)
			end
		end

		def process_handshake
			return false if @data.empty?

			data = @data.to_str

			if data == "<policy-file-request/>\0"
				write_policy_file
				@state = :invalid_state
				return false
			end

			begin
				@http11_nbytes = @http11.execute(@request, data, @http11_nbytes)
			rescue
				on_error "invalid HTTP header, parsing fails"
				@state = :invalid_state
				close
			end

			return false unless @http11.finished?

			@data.read(@http11_nbytes-1)
			remove_instance_variable(:@http11)
			remove_instance_variable(:@http11_nbytes)

			@request.delete(DummyIO::KEY)

			unless @request["REQUEST_METHOD"] == "GET"
				raise RuntimeError, "Request method must be GET"
			end

			unless @request['HTTP_CONNECTION'] == 'Upgrade' and @request['HTTP_UPGRADE'] == 'WebSocket'
				raise RequestError, "Connection and Upgrade headers required"
			end

			@state = :process_frame_header

			version = @request['HTTP_SEC_WEBSOCKET_KEY1'] ? 76 : 75
			begin
				case version
				when 75
					extend Spec75
				when 76
					extend Spec76
				end

				if handshake
					on_open
				end

			rescue
				on_bad_request
				return false
			end

			return true
		end

		def on_bad_request
			write "HTTP/1.1 400 Bad request\r\n\r\n"
			close
		end

		def process_frame_header
			return false if @data.empty?

			@frame_type = @data.read(1).to_i
			if (@frame_type & 0x80) == 0x80
				@binary_length = 0
				@state = :process_binary_frame_header
			else
				@state = :process_text_frame
			end

			return true
		end

		def process_binary_frame_header
			until @data.empty?

				b = @data.read(1).to_i
				b_v = b & 0x7f
				@binary_length = (@binary_length<<7) | b_v

				if (b & 0x80) == 0x80
					if @binary_length == 0
						# If the /frame type/ is 0xFF and the /length/ was 0
						write "\xff\x00"
						@state = :invalid_state
						close
						return false
					end

					@state = :process_binary_frame
					return true
				end

			end
			return false
		end

		def process_binary_frame
			return false if @data.size < @binary_length

			# Just discard the read bytes.
			@data.read(@binary_length)

			@state = :process_frame_header
			return true
		end

		def process_text_frame
			return false if @data.empty?

			pos = @data.to_str.index("\xff")
			if pos.nil?
				return false
			end

			msg = @data.read(pos)
			@data.read(1)  # read 0xff byte

			@state = :process_frame_header

			if @frame_type != 0x00
				# discard the data
				return true
			end

			msg.force_encoding('UTF-8') if HAVE_ENCODING
			on_message(msg)

			return true
		end

		def write_policy_file
			write %[<cross-domain-policy><allow-access-from domain="*" to-ports="*"/></cross-domain-policy>\0]
		end

		def ssl?
			false
		end

		private

		def invalid_state
			raise RuntimeError, "invalid state"
		end
	end

	class SSLWebSocket < WebSocket
		def on_connect
			extend SSL
			ssl_server_start
		end

		def ssl?
			true
		end
	end
end

