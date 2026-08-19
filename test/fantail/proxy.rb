# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fantail"
require "sus/fixtures/async/reactor_context"
require_relative "fixtures"

describe Fantail::Proxy do
	include Sus::Fixtures::Async::ReactorContext
	include Fantail::Fixtures
	
	let(:request) {Protocol::HTTP::Request["GET", "/"]}
	
	it "returns 503 without any backends" do
		registry = make_registry
		proxy = subject.new(registry)
		
		response = proxy.call(request)
		
		expect(response.status).to be == 503
	ensure
		response&.close
		registry&.close
	end
	
	it "releases processing capacity at response headers" do
		registry = make_registry(exchange_limit: 2)
		registry.replace([{name: "worker-1", url: "http://127.0.0.1:9301"}])
		proxy = subject.new(registry)
		client = @clients.fetch("worker-1")
		
		first = proxy.call(Protocol::HTTP::Request["GET", "/first"])
		second = proxy.call(Protocol::HTTP::Request["GET", "/second"])
		
		expect(client.calls.size).to be == 2
		expect(registry["worker-1"].exchanges).to be == 2
		
		third_task = Async do
			proxy.call(Protocol::HTTP::Request["GET", "/third"])
		end
		
		Fiber.scheduler.yield
		expect(client.calls.size).to be == 2
		
		first.close
		third = third_task.wait
		
		expect(client.calls.size).to be == 3
	ensure
		first&.close
		second&.close
		third&.close
		third_task&.stop
		registry&.close
	end
	
	it "reuses a backend after a failure before response headers" do
		client = Fantail::Fixtures::Client.new do |_request, count|
			raise IOError, "Failed" if count == 1
			
			Protocol::HTTP::Response[200, {}, ["Okay"]]
		end
		
		registry = make_registry{|_endpoint| client}
		registry.replace([{name: "worker-1", url: "http://127.0.0.1:9301"}])
		proxy = subject.new(registry)
		
		failed = proxy.call(Protocol::HTTP::Request["GET", "/failed"])
		succeeded = proxy.call(Protocol::HTTP::Request["GET", "/succeeded"])
		
		expect(failed.status).to be == 502
		expect(succeeded.status).to be == 200
		expect(client.calls.size).to be == 2
	ensure
		failed&.close
		succeeded&.close
		registry&.close
	end
	
	it "releases responses without a body immediately" do
		client = Fantail::Fixtures::Client.new do
			Protocol::HTTP::Response.new(nil, 204)
		end
		
		registry = make_registry{|_endpoint| client}
		registry.replace([{name: "worker-1", url: "http://127.0.0.1:9301"}])
		proxy = subject.new(registry)
		
		response = proxy.call(Protocol::HTTP::Request["GET", "/empty"])
		
		expect(response.status).to be == 204
		expect(registry["worker-1"].exchanges).to be == 0
	ensure
		response&.close
		registry&.close
	end
	
	it "releases the exchange if response wrapping fails" do
		broken_response = Object.new
		broken_response.define_singleton_method(:body){Protocol::HTTP::Body::Buffered.wrap(["Okay"])}
		broken_response.define_singleton_method(:body=){|_body| raise TypeError, "Cannot wrap body!"}
		
		client = Fantail::Fixtures::Client.new{broken_response}
		registry = make_registry{|_endpoint| client}
		registry.replace([{name: "worker-1", url: "http://127.0.0.1:9301"}])
		proxy = subject.new(registry)
		
		response = proxy.call(Protocol::HTTP::Request["GET", "/broken"])
		
		expect(response.status).to be == 502
		expect(registry["worker-1"].exchanges).to be == 0
	ensure
		response&.close
		registry&.close
	end
end
