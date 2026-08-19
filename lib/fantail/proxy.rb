# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/http/request"
require "protocol/http/response"

require_relative "response_body"

module Fantail
	# Routes HTTP requests through the registry's global admission queue.
	class Proxy
		# Initialize an HTTP proxy.
		# @parameter registry [Registry] The backend registry.
		def initialize(registry)
			@registry = registry
		end
		
		# Route a request to the next available backend.
		# @parameter request [Protocol::HTTP::Request] The downstream request.
		# @returns [Protocol::HTTP::Response] The upstream or generated response.
		def call(request)
			unless backend = @registry.acquire
				return Protocol::HTTP::Response[503, {"content-type" => "text/plain"}, ["No backends available.\n"]]
			end
			
			reservation = :processing
			upstream_request = build_request(request)
			response = backend.call(upstream_request)
			backend.processed
			reservation = :exchange
			
			if body = response.body
				response.body = ResponseBody.new(body){backend.release}
			else
				backend.release
			end
			reservation = nil
			
			return response
		rescue => error
			case reservation
			when :processing
				backend.failed
			when :exchange
				backend.release
			end
			
			return Protocol::HTTP::Response[502, {"content-type" => "text/plain"}, ["Bad Gateway: #{error.class}\n"]]
		end
		
		protected
		
		def build_request(request)
			upstream_request = Protocol::HTTP::Request.new(
				nil,
				nil,
				request.method,
				request.path,
				nil,
				request.headers,
				request.body,
				request.protocol,
				request.interim_response,
			)
			
			# Transfer ownership of the request body to the upstream request:
			request.body = nil
			
			return upstream_request
		end
	end
end
