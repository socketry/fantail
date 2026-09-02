# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/http/response"

module Fantail
	module Fixtures
		class Client
			def initialize(&response)
				@response = response || proc{Protocol::HTTP::Response[200, {}, ["Okay"]]}
				@calls = []
				@closed = false
			end
			
			attr :calls
			
			def call(request)
				@calls << request
				@response.call(request, @calls.size)
			end
			
			def close
				@closed = true
			end
			
			def closed?
				@closed
			end
		end
		
		def make_registry(exchange_limit: 8, permit_limit: 1, &client_factory)
			@clients = {}
			
			backend_factory = proc do |endpoint, exchange_limit, backend_permit_limit, available|
				client = client_factory&.call(endpoint) || Client.new
				@clients[endpoint.name] = client
				
				Backend.new(endpoint, client, exchange_limit: exchange_limit, permit_limit: backend_permit_limit, &available)
			end
			
			Registry.new(exchange_limit: exchange_limit, permit_limit: permit_limit, backend_factory: backend_factory)
		end
	end
end
