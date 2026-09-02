# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/server"

require_relative "registry"
require_relative "proxy"
require_relative "control"
require_relative "configuration"

module Fantail
	# Runs the HTTP load balancer and endpoint-control server together.
	class Server
		# Initialize a Fantail server.
		# @parameter endpoint [Async::HTTP::Endpoint] The downstream HTTP endpoint.
		# @parameter control_endpoint [IO::Endpoint] The async-bus control endpoint.
		# @parameter exchange_limit [Integer] The maximum outstanding responses per backend.
		# @parameter configuration [Configuration] Request classification and scheduling policy.
		def initialize(endpoint, control_endpoint, exchange_limit: 8, configuration: Configuration.default)
			@registry = Registry.new(exchange_limit: exchange_limit, permit_limit: configuration.permit_limit)
			@proxy = Proxy.new(@registry, configuration: configuration)
			@http_server = Async::HTTP::Server.new(@proxy, endpoint)
			@control_server = Control.new(control_endpoint, @registry)
		end
		
		# @attribute [Registry] The server's endpoint registry.
		attr :registry
		
		# @attribute [Scheduler] The central request scheduler.
		def scheduler
			@proxy.scheduler
		end
		
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
		
		# Stop pending requests and close the endpoint registry.
		def close
			@proxy.scheduler.close
			@registry.close
		end
	end
end
