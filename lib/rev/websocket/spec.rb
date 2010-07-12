require 'digest/md5'

module Rev
	class WebSocket < TCPSocket

		module Spec75
			protected

			def handshake
				schema = (ssl? ? 'wss' : 'ws')
				location = "#{schema}://#{@request['HTTP_HOST']}#{@request['REQUEST_URI']}"

				upgrade =  "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
				upgrade << "Upgrade: WebSocket\r\n"
				upgrade << "Connection: Upgrade\r\n"
				upgrade << "WebSocket-Origin: #{@request['HTTP_ORIGIN']}\r\n"
				upgrade << "WebSocket-Location: #{location}\r\n\r\n"

				write upgrade

				return true  # opened
			end
		end

		module Spec76
			protected

			def handshake
				@state_save = @state
				@state = :process_challenge_response

				return false # not yet opened
			end

			def process_challenge_response
				return false if @data.size < 8

				key_3 = @data.read(8)

				@state = remove_instance_variable(:@state_save)

				challenge_response = do_challenge_response(
					@request['HTTP_SEC_WEBSOCKET_KEY1'],
					@request['HTTP_SEC_WEBSOCKET_KEY2'],
					key_3)

				schema = (ssl? ? 'wss' : 'ws')
				location = "#{schema}://#{@request['HTTP_HOST']}#{@request['REQUEST_URI']}"

				upgrade =  "HTTP/1.1 101 WebSocket Protocol Handshake\r\n"
				upgrade << "Upgrade: WebSocket\r\n"
				upgrade << "Connection: Upgrade\r\n"
				upgrade << "Sec-WebSocket-Location: #{location}\r\n"
				upgrade << "Sec-WebSocket-Origin: #{@request['HTTP_ORIGIN']}\r\n"
				if proto = @request['HTTP_SEC_WEBSOCKET_PROTOCOL']
					# FIXME server is requed to confirm the subprotocol of the connection
					upgrade << "Sec-WebSocket-Protocol: #{proto}\r\n"
				end
				upgrade << "\r\n"
				upgrade << challenge_response

				write upgrade

				on_open

				return true

			rescue
				on_bad_request
				return false
			end

			private
			def do_challenge_response(key_1, key_2, key_3)
				key_number_1 = key_1.scan(/[0-9]/).join.to_i
				key_number_2 = key_2.scan(/[0-9]/).join.to_i
				spaces_1 = key_1.count(' ')
				spaces_2 = key_2.count(' ')

				if spaces_1 == 0 || spaces_2 == 0
					raise RuntimeError, "invalid challenge key"
				end

				if key_number_1 % spaces_1 != 0 || key_number_2 % spaces_2 != 0
					raise RuntimeError, "invalid challenge key"
				end

				part_1 = key_number_1 / spaces_1
				part_2 = key_number_2 / spaces_2

				challenge = [part_1, part_2].pack('NN') + key_3[0,8]
				response = Digest::MD5.digest(challenge)

				return response

			rescue
				on_bad_request
			end
		end

	end
end

