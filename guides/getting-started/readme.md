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
	configuration = Fantail::Configuration.load("config/fantail.rb")
	
	server = Fantail::Server.new(
		Async::HTTP::Endpoint.parse("http://0.0.0.0:9292"),
		IO::Endpoint.tcp("0.0.0.0", 9293),
		configuration: configuration,
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

Each backend has a configurable number of request-processing permits and response exchanges. A processing permit is released as soon as upstream response headers arrive. The exchange remains reserved until the response body closes.

This allows a worker to begin another request while an earlier response streams, without allowing an unbounded number of streaming responses to accumulate.

The scheduler owns all permits. Request queues can decide which workers are eligible and express a soft preference between them, but cannot reserve capacity independently. If the preferred worker is unavailable, the scheduler remains work-conserving and uses another eligible worker.

## Request Queues

Fantail configuration is trusted application Ruby evaluated using a scoped configuration loader:

~~~ ruby
# config/fantail.rb
queue :liquid do
	match{|request| request.path.start_with?("/render")}
	balance :spread
	depth_limit 500
	wait_limit 0.25
	shed status: 429, retry_after: 1
end

queue :grpc do
	match do |request|
		request.headers["content-type"]&.start_with?("application/grpc")
	end
	
	balance :pack, affinity: :grpc
end

default_queue :liquid
pending_limit 1_000
permit_limit 1
~~~

Configuration can be split into files relative to the file being evaluated using `load_file "queues.rb"`.

Matchers are evaluated in definition order, followed by the default queue. Across queues, the oldest eligible head request is dispatched first. If that request has no eligible worker, another queue can use the available permit.

The built-in `:spread` policy prefers the least-active worker. The `:pack` policy prefers a worker already processing the specified affinity, while remaining bounded by its permits. An application can supply a policy object implementing `select(backends, queue:, request:)`, and can restrict hard eligibility with `queue.eligible`.

## Load Shedding

`depth_limit` bounds requests actually waiting in a queue; immediately dispatchable requests do not count against it. `pending_limit` provides a global bound across all queues. `wait_limit` bounds actual queue residence time in seconds. Rejected requests use the response configured by `shed`, which defaults to HTTP 429.

Applications can add an admission policy with either a block or an object implementing `admit?(request, queue:, pending:)`:

~~~ ruby
queue :default do
	admit do |request, queue:, pending:|
		pending < application_limit_for(queue.name)
	end
end
~~~
