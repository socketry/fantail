# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Fantail
	# Represents a live backend client and its admission state.
	class Backend
		# Initialize a backend.
		# @parameter endpoint [Endpoint] The endpoint served by this backend.
		# @parameter client [Interface(:call, :close)] The HTTP client for the endpoint.
		# @parameter exchange_limit [Integer] The maximum number of outstanding response exchanges.
		# @yields {|backend| ...} Invoked when the backend can accept another request.
		def initialize(endpoint, client, exchange_limit:, &available)
			raise ArgumentError, "Exchange limit must be positive!" unless exchange_limit.positive?
			
			@endpoint = endpoint
			@client = client
			@exchange_limit = exchange_limit
			@available = available
			
			@guard = Thread::Mutex.new
			@active = true
			@processing = false
			@exchanges = 0
			@queued = false
			@closed = false
		end
		
		# @attribute [Endpoint] The endpoint served by this backend.
		attr :endpoint
		
		# @attribute [String] The stable backend name.
		def name
			@endpoint.name
		end
		
		# @attribute [Integer] The maximum number of outstanding response exchanges.
		attr :exchange_limit
		
		# Start advertising this backend as available.
		def start
			notify_available
		end
		
		# Reserve the processing slot and one response exchange.
		# @returns [Boolean] Whether the backend was successfully reserved.
		def reserve
			@guard.synchronize do
				@queued = false
				
				if @active && !@processing && @exchanges < @exchange_limit
					@processing = true
					@exchanges += 1
					return true
				end
			end
			
			return false
		end
		
		# Send a request to the backend.
		# @parameter request [Protocol::HTTP::Request] The upstream request.
		# @returns [Protocol::HTTP::Response] The upstream response.
		def call(request)
			@client.call(request)
		end
		
		# Release the request-processing slot after response headers arrive.
		def processed
			@guard.synchronize do
				raise RuntimeError, "Backend is not processing a request!" unless @processing
				@processing = false
			end
			
			notify_available
		end
		
		# Release both reservations when a request fails before response headers.
		def failed
			close = @guard.synchronize do
				raise RuntimeError, "Backend is not processing a request!" unless @processing
				@processing = false
				@exchanges -= 1
				should_close?
			end
			
			notify_available
			close_client if close
		end
		
		# Release an outstanding response exchange.
		def release
			close = @guard.synchronize do
				raise RuntimeError, "Backend has no outstanding exchange!" unless @exchanges.positive?
				@exchanges -= 1
				should_close?
			end
			
			notify_available
			close_client if close
		end
		
		# Retire this backend without interrupting outstanding responses.
		def retire
			close = @guard.synchronize do
				@active = false
				should_close?
			end
			
			close_client if close
		end
		
		# @returns [Boolean] Whether this backend still accepts new requests.
		def active?
			@guard.synchronize{@active}
		end
		
		# @returns [Integer] The number of outstanding response exchanges.
		def exchanges
			@guard.synchronize{@exchanges}
		end
		
		# @returns [Boolean] Whether a request is waiting for response headers.
		def processing?
			@guard.synchronize{@processing}
		end
		
		protected
		
		def notify_available
			notify = @guard.synchronize do
				if @active && !@processing && @exchanges < @exchange_limit && !@queued
					@queued = true
					true
				else
					false
				end
			end
			
			@available.call(self) if notify
		end
		
		def should_close?
			!@active && !@processing && @exchanges.zero? && !@closed
		end
		
		def close_client
			close = @guard.synchronize do
				unless @closed
					@closed = true
					true
				end
			end
			
			@client.close if close
		end
	end
end
