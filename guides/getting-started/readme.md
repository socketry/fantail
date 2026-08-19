# Getting Started

This guide explains how to run Fantail and publish HTTP worker endpoints.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add fantail
~~~

## Server

Fantail exposes an HTTP endpoint for downstream traffic and an async-bus endpoint for worker registration:

~~~ ruby
require "async"
require "async/http/endpoint"
require "fantail"
require "io/endpoint"

Sync do
	server = Fantail::Server.new(
		Async::HTTP::Endpoint.parse("http://0.0.0.0:9292"),
		IO::Endpoint.tcp("0.0.0.0", 9293),
	)
	
	server.run.wait
end
~~~

## Endpoint Publication

A monitor keeps the desired endpoint set locally. Registration callbacks only update this local state and enqueue a change; they do not wait for the control connection.

~~~ ruby
require "async"
require "fantail"
require "io/endpoint"

Sync do
	monitor = Fantail::Monitor.new(IO::Endpoint.tcp("fantail", 9293))
	monitor.replace([
		Fantail::Endpoint.new("worker-1", "http://127.0.0.1:9301"),
		Fantail::Endpoint.new("worker-2", "http://127.0.0.1:9302"),
	])
	
	monitor.run.wait
end
~~~

After connecting, the monitor performs a complete replacement. It then publishes additions, replacements, and removals as deltas. A reconnect always begins with another complete replacement so missed deltas cannot leave the registry stale.

## Admission Semantics

Each backend has one request-processing slot and a configurable number of response exchanges. The processing slot is released as soon as upstream response headers arrive. The exchange remains reserved until the response body closes.

This allows a worker to begin another request while an earlier response streams, without allowing an unbounded number of streaming responses to accumulate.
