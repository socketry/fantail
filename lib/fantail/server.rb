# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/server"

require_relative "registry"
require_relative "proxy"
require_relative "control"

module Fantail
	# Runs the HTTP load balancer and endpoint-control server together.
	class Server
		# Initialize a Fantail server.
		# @parameter endpoint [Async::HTTP::Endpoint] The downstream HTTP endpoint.
		# @parameter control_endpoint [IO::Endpoint] The async-bus control endpoint.
		# @parameter exchange_limit [Integer] The maximum outstanding responses per backend.
		def initialize(endpoint, control_endpoint, exchange_limit: 8)
			@registry = Registry.new(exchange_limit: exchange_limit)
			@proxy = Proxy.new(@registry)
			@http_server = Async::HTTP::Server.new(@proxy, endpoint)
			@control_server = Control.new(control_endpoint, @registry)
		end
		
		# @attribute [Registry] The server's endpoint registry.
		attr :registry
		
		# Run the HTTP and control servers.
		# @parameter parent [Interface(:async)] The parent task.
		# @returns [Async::Task] The server task.
		def run(parent: Async::Task.current)
			parent.async do |task|
				task.async do
					@control_server.accept
				end
				
				@http_server.run.wait
			end
		end
		
		# Close the endpoint registry.
		def close
			@registry.close
		end
	end
end
