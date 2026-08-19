# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/bus/server"

module Fantail
	# Exposes a registry over async-bus for endpoint publication.
	class Control < Async::Bus::Server
		# Initialize a control server.
		# @parameter endpoint [IO::Endpoint] The endpoint used for registry updates.
		# @parameter registry [Registry] The registry to expose.
		def initialize(endpoint, registry)
			super(endpoint)
			@registry = registry
		end
		
		protected def connected!(connection)
			connection.bind(:registry, @registry)
		end
	end
end
