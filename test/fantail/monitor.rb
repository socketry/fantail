# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fantail"
require "sus/fixtures/async/reactor_context"
require "tmpdir"

describe Fantail::Monitor do
	include Sus::Fixtures::Async::ReactorContext
	
	class RecordingRegistry
		def initialize
			@replacements = Async::Queue.new
			@updates = Async::Queue.new
		end
		
		attr :replacements
		attr :updates
		
		def replace(endpoints)
			@replacements.enqueue(endpoints)
		end
		
		def update(upserted, removed)
			@updates.enqueue([upserted, removed])
		end
	end
	
	def wait_until
		100.times do
			return true if yield
			sleep(0.01)
		end
		
		return false
	end
	
	it "publishes an initial replacement followed by deltas" do
		Dir.mktmpdir do |directory|
			endpoint = Async::Bus::Protocol.local_endpoint(File.join(directory, "fantail.ipc"))
			bound_endpoint = endpoint.bound
			
			registry = Fantail::Registry.new
			control = Fantail::Control.new(bound_endpoint, registry)
			control_task = Async{control.accept}
			
			monitor = subject.new(endpoint)
			monitor.replace([{name: "worker-1", url: "http://127.0.0.1:9301"}])
			monitor_task = monitor.run
			
			expect(wait_until{registry.names == ["worker-1"]}).to be_truthy
			
			monitor.upsert(name: "worker-2", url: "http://127.0.0.1:9302")
			monitor.remove("worker-1")
			
			expect(wait_until{registry.names == ["worker-2"]}).to be_truthy
		ensure
			monitor_task&.stop
			control_task&.stop
			registry&.close
			bound_endpoint&.close
		end
	end
	
	it "performs a complete replacement after reconnecting" do
		monitor = subject.new(IO::Endpoint.tcp("127.0.0.1", 9293))
		monitor.replace([{name: "worker-1", url: "http://127.0.0.1:9301"}])
		
		first_registry = RecordingRegistry.new
		first_connection = Async do
			monitor.send(:synchronize, first_registry)
		end
		
		expect(first_registry.replacements.dequeue).to be == [
			{"name" => "worker-1", "url" => "http://127.0.0.1:9301"},
		]
		
		monitor.upsert(name: "worker-2", url: "http://127.0.0.1:9302")
		expect(first_registry.updates.dequeue).to be == [
			[{"name" => "worker-2", "url" => "http://127.0.0.1:9302"}],
			[],
		]
		
		first_connection.stop
		monitor.remove("worker-1")
		
		second_registry = RecordingRegistry.new
		second_connection = Async do
			monitor.send(:synchronize, second_registry)
		end
		
		expect(second_registry.replacements.dequeue).to be == [
			{"name" => "worker-2", "url" => "http://127.0.0.1:9302"},
		]
		expect(monitor.endpoints).to be == [
			{"name" => "worker-2", "url" => "http://127.0.0.1:9302"},
		]
	ensure
		first_connection&.stop
		second_connection&.stop
	end
end
