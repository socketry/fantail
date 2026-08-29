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
		# @parameter permit_limit [Integer] The maximum number of concurrent processing permits.
		# @yields {|backend| ...} Invoked when the backend can accept another request.
		def initialize(endpoint, client, exchange_limit:, permit_limit: 1, &available)
			raise ArgumentError, "Exchange limit must be positive!" unless exchange_limit.positive?
			raise ArgumentError, "Permit limit must be positive!" unless permit_limit.positive?
			
			@endpoint = endpoint
			@client = client
			@exchange_limit = exchange_limit
			@permit_limit = permit_limit
			@available = available
			
			@guard = Thread::Mutex.new
			@active = true
			@processing = 0
			@processing_by_queue = Hash.new(0)
			@exchanges = 0
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
		def reserve(queue_name = :default)
			@guard.synchronize do
				if @active && @processing < @permit_limit && @exchanges < @exchange_limit
					@processing += 1
					@processing_by_queue[queue_name] += 1
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
		def processed(queue_name = :default)
			@guard.synchronize do
				release_processing(queue_name)
			end
			
			notify_available
		end
		
		# Release both reservations when a request fails before response headers.
		def failed(queue_name = :default)
			close = @guard.synchronize do
				release_processing(queue_name)
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
			@guard.synchronize{@processing.positive?}
		end
		
		# @returns [Integer] The number of active processing permits.
		def processing
			@guard.synchronize{@processing}
		end
		
		# @returns [Integer] The number of active permits for the given queue affinity.
		def processing_for(queue_name)
			@guard.synchronize{@processing_by_queue[queue_name]}
		end
		
		# @returns [Boolean] Whether another request can be admitted.
		def available?
			@guard.synchronize{@active && @processing < @permit_limit && @exchanges < @exchange_limit}
		end
		
		protected
		
		def notify_available
			@available.call(self) if available?
		end
		
		def should_close?
			!@active && @processing.zero? && @exchanges.zero? && !@closed
		end
		
		def release_processing(queue_name)
			raise RuntimeError, "Backend is not processing a request!" unless @processing.positive?
			raise RuntimeError, "Backend is not processing queue #{queue_name.inspect}!" unless @processing_by_queue[queue_name].positive?
			
			@processing -= 1
			@processing_by_queue[queue_name] -= 1
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
