# Publisher/Subscriber-style message routing

require 'rubygems'
require 'rev/websocket'
require 'json'

class PubSub
	def initialize
		@subscriber = {}
		@seqid = 0
	end

	def subscribe(&block)
		sid = @seqid += 1
		@subscriber[sid] = block
		return sid
	end

	def unsubscribe(key)
		@subscriber.delete(key)
	end

	def publish(data)
		@subscriber.reject! {|sid,block|
			begin
				block.call(data)
				false
			rescue
				true
			end
		}
	end

	def size
		@subscriber.size
	end
end

$pubsub = PubSub.new
$record = []

class ShoutChatConnection < Rev::WebSocket
	def on_open
		@host = request['HTTP_HOST']
		return unless @host
		puts "connection opened: <#{@host}>"

		@sid = $pubsub.subscribe {|data|
			send_message data
		}
		$pubsub.publish(["count", $pubsub.size].to_json)
		$record.each {|data| send_message data }
	end

	def on_message(data)
		puts "broadcasting: <#{@host}> #{data}"

		$pubsub.publish(data)
		$record.push(data)
		$record.shift while $record.size > 20
	end

	def on_close
		return unless @host
		puts "connection closed: <#{@host}>"

		$pubsub.unsubscribe(@sid)
		$pubsub.publish(["count", $pubsub.size].to_json)
	end
end

host = '0.0.0.0'
port = ARGV[0] || 8081

server = Rev::WebSocketServer.new(host, port, ShoutChatConnection)
server.attach(Rev::Loop.default)

puts "start on #{host}:#{port}"

Rev::Loop.default.run

