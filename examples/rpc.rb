# RPC push
# This program receives messages.
# See ./rpc file which sends messages to this program.

require 'rubygems'
require 'rev/websocket'
require 'msgpack/rpc'
require 'json'

$sockets = {}

class MyConnection < Rev::WebSocket
	def on_open
		puts "WebSocket opened from '#{peeraddr[2]}': request=#{request.inspect}"
		$sockets[self] = self
	end

	def on_close
		puts "WebSocket closed"
		$sockets.delete(self)
	end
end

class RPCServer
	def push_data(data)
		$sockets.each_key {|sock|
			sock.send_message(data.to_json)
		}
		nil
	end
end

host = '0.0.0.0'
port = ARGV[0] || 8081

rpc_port = 18800

loop = Rev::Loop.default

ws = Rev::WebSocketServer.new(host, port, MyConnection)
ws.attach(loop)

rpc = MessagePack::RPC::Server.new(loop)
rpc.listen('127.0.0.1', rpc_port, RPCServer.new)

loop.run

