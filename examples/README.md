Rev-WebSocket Examlpes
======================

Documents for *rev-websocket* is available at [frsyuki's rev-websocket repository](http://github.com/frsyuki/rev-websocket).


## Echo server

    $ gem install rev-websocket
    $ ruby ./echo

A HTTP server runs on localhost:8080 and WebSocket server runs on localhost:8081.

Then access to [htt://localhost:8080/echo.html](http://localhost:8080/echo.html).


## RPC push

With RPC (Remote Procedure Call), you can push messages to browsers from programs separated from the WebSocket server.

In this example, a Sinatra based web appliction pushes messages using MessagePack-RPC, a simple cross-language RPC library.

    $ gem install msgpack-rpc
    $ gem install rev-websocket
    $ gem install sinatra
    $ gem install json
    $ ruby ./rpc

Then access to [htt://localhost:8080/](http://localhost:8080/).


## ShoutChat

ShoutChat is a simple browser-based chat application.

    $ gem install rev-websocket
    $ gem install json
    $ ruby ./shoutchat

Then access to [htt://localhost:8080/shoutchat.html](http://localhost:8080/shoutchat.html).

