# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fantail"
require "sus/fixtures/async/reactor_context"
require_relative "fixtures"

describe Fantail::Registry do
	include Sus::Fixtures::Async::ReactorContext
	include Fantail::Fixtures
	
	let(:registry) {make_registry}
	
	after do
		registry.close
	end
	
	it "can replace and update endpoints" do
		expect(registry.replace([
			{name: "worker-1", url: "http://127.0.0.1:9301"},
			{name: "worker-2", url: "http://127.0.0.1:9302"},
		])).to be == 2
		
		expect(registry.names).to be == ["worker-1", "worker-2"]
		
		expect(registry.update(
			[{name: "worker-3", url: "http://127.0.0.1:9303"}],
			["worker-1"],
		)).to be == 2
		
		expect(registry.names).to be == ["worker-2", "worker-3"]
	end
	
	it "does not replace an unchanged backend" do
		description = {name: "worker-1", url: "http://127.0.0.1:9301"}
		registry.replace([description])
		client = @clients.fetch("worker-1")
		
		registry.update([description], [])
		
		expect(@clients.fetch("worker-1")).to be_equal(client)
		expect(client).not.to be(:closed?)
	end
	
	it "drains a retired backend before closing it" do
		registry.replace([{name: "worker-1", url: "http://127.0.0.1:9301"}])
		backend = registry.acquire
		client = @clients.fetch("worker-1")
		
		backend.processed
		registry.update([], ["worker-1"])
		
		expect(client).not.to be(:closed?)
		expect(backend).not.to be(:active?)
		
		backend.release
		
		expect(client).to be(:closed?)
	end
	
	it "only permits one request to be processed at a time" do
		registry.replace([{name: "worker-1", url: "http://127.0.0.1:9301"}])
		backend = registry.acquire
		
		expect(backend.name).to be == "worker-1"
		expect(backend).to be(:processing?)
		expect(backend.reserve).to be_falsey
		
		backend.failed
		expect(backend).not.to be(:processing?)
	end
	
	it "wakes an acquisition when a permit is released" do
		registry.replace([{name: "worker-1", url: "http://127.0.0.1:9301"}])
		first = registry.acquire
		second_task = Async{registry.acquire}
		Fiber.scheduler.yield
		
		expect(second_task).not.to be(:finished?)
		first.failed
		first = nil
		
		second = second_task.wait
		expect(second.name).to be == "worker-1"
	ensure
		first&.failed
		second&.failed
		second_task&.stop
	end
	
	it "supports multiple processing permits" do
		registry.close
		registry = make_registry(permit_limit: 2)
		registry.replace([{name: "worker-1", url: "http://127.0.0.1:9301"}])
		backend = registry["worker-1"]
		
		expect(backend.reserve(:grpc)).to be_truthy
		expect(backend.reserve(:grpc)).to be_truthy
		expect(backend.reserve(:grpc)).to be_falsey
		expect(backend.processing_for(:grpc)).to be == 2
		
		backend.failed(:grpc)
		backend.failed(:grpc)
	ensure
		registry&.close
	end
	
	it "returns nil when no endpoints exist" do
		expect(registry.acquire).to be_nil
	end
end
