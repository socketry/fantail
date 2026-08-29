# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/http/request"
require "protocol/http/response"

require_relative "response_body"
require_relative "scheduler"

module Fantail
	# Routes HTTP requests through the configured admission queues.
	class Proxy
		# Initialize an HTTP proxy.
		# @parameter registry [Registry] The backend registry.
		# @parameter configuration [Configuration] Request classification and scheduling policy.
		def initialize(registry, configuration: Configuration.default)
			@scheduler = Scheduler.new(registry, configuration)
		end
		
		attr :scheduler
		
		# Route a request to the next available backend.
		# @parameter request [Protocol::HTTP::Request] The downstream request.
		# @returns [Protocol::HTTP::Response] The upstream or generated response.
		def call(request)
			unless backend_reservation = @scheduler.acquire(request)
				return Protocol::HTTP::Response[503, {"content-type" => "text/plain"}, ["No backends available.\n"]]
			end
			
			return backend_reservation.response if backend_reservation.is_a?(Scheduler::Rejection)
			
			reservation = :processing
			backend = backend_reservation.backend
			upstream_request = build_request(request)
			response = backend.call(upstream_request)
			backend_reservation.processed
			reservation = :exchange
			
			if body = response.body
				response.body = ResponseBody.new(body){backend_reservation.release}
			else
				backend_reservation.release
			end
			reservation = nil
			
			return response
		rescue => error
			case reservation
			when :processing
				backend_reservation.failed
			when :exchange
				backend_reservation.release
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
