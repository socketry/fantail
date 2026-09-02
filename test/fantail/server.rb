# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fantail"
require "sus/fixtures/async/reactor_context"
require "tmpdir"

describe Fantail::Server do
	include Sus::Fixtures::Async::ReactorContext
	
	def bound_http_endpoint
		bound_endpoint = IO::Endpoint.tcp("127.0.0.1", 0).bound
		port = bound_endpoint.sockets.first.local_address.ip_port
		endpoint = Async::HTTP::Endpoint.parse("http://127.0.0.1:#{port}", bound_endpoint)
		
		return endpoint, bound_endpoint, port
	end
	
	def wait_until
		100.times do
			return true if yield
			sleep(0.01)
		end
		
		return false
	end
	
	it "routes requests to endpoints published over the control connection" do
		Dir.mktmpdir do |directory|
			worker_endpoint, worker_bound_endpoint, worker_port = bound_http_endpoint
			worker_server = Async::HTTP::Server.for(worker_endpoint) do |request|
				Protocol::HTTP::Response[200, {"x-worker-path" => request.path}, ["Hello from worker!"]]
			end
			worker_task = worker_server.run
			
			downstream_endpoint, downstream_bound_endpoint, downstream_port = bound_http_endpoint
			control_endpoint = Async::Bus::Protocol.local_endpoint(File.join(directory, "fantail.ipc"))
			control_bound_endpoint = control_endpoint.bound
			
			server = subject.new(downstream_endpoint, control_bound_endpoint)
			expect(server.scheduler).to be_a(Fantail::Scheduler)
			server_task = server.run
			
			monitor = Fantail::Monitor.new(control_endpoint)
			monitor.replace([
				{name: "worker-1", url: "http://127.0.0.1:#{worker_port}"},
			])
			monitor_task = monitor.run
			
			expect(wait_until{server.registry.names == ["worker-1"]}).to be_truthy
			
			client = Async::HTTP::Client.new(
				Async::HTTP::Endpoint.parse("http://127.0.0.1:#{downstream_port}"),
				retries: 0,
			)
			response = client.get("/hello")
			
			expect(response.status).to be == 200
			expect(response.headers["x-worker-path"]).to be == ["/hello"]
			expect(response.read).to be == "Hello from worker!"
		ensure
			response&.close
			client&.close
			monitor_task&.stop
			server_task&.stop
			server&.close
			worker_task&.stop
			control_bound_endpoint&.close
			downstream_bound_endpoint&.close
			worker_bound_endpoint&.close
		end
	end
end
