# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/bus/controller"

require_relative "endpoint"
require_relative "backend"

module Fantail
	# Maintains live backends and notifies the scheduler when capacity changes.
	class Registry < Async::Bus::Controller
		# Initialize an endpoint registry.
		# @parameter exchange_limit [Integer] The maximum outstanding responses per backend.
		# @parameter permit_limit [Integer] The maximum active processing permits per backend.
		# @parameter backend_factory [#call(endpoint, exchange_limit, permit_limit, available) | Nil] An optional backend construction strategy.
		def initialize(exchange_limit: 8, permit_limit: 1, backend_factory: nil)
			@exchange_limit = exchange_limit
			@permit_limit = permit_limit
			@backend_factory = backend_factory || self.method(:make_backend)
			
			@guard = Thread::Mutex.new
			@backends = {}
			@available = nil
			@closed = false
		end
		
		# Replace the complete endpoint set.
		# @parameter descriptions [Array(Endpoint | Hash)] The desired endpoints.
		# @returns [Integer] The resulting endpoint count.
		def replace(descriptions)
			endpoints = descriptions.map{|description| Endpoint.coerce(description)}
			names = endpoints.map(&:name)
			
			current_names = @guard.synchronize{@backends.keys}
			self.update(endpoints, current_names - names)
		end
		
		# Apply endpoint additions, replacements, and removals.
		# @parameter upserted [Array(Endpoint | Hash)] Endpoints to add or replace.
		# @parameter removed [Array(String)] Endpoint names to remove.
		# @returns [Integer] The resulting endpoint count.
		def update(upserted, removed)
			retired = []
			started = []
			
			@guard.synchronize do
				raise IOError, "Registry is closed!" if @closed
				
				removed.each do |name|
					if backend = @backends.delete(name.to_s)
						retired << backend
					end
				end
				
				upserted.each do |description|
					endpoint = Endpoint.coerce(description)
					current = @backends[endpoint.name]
					
					next if current&.endpoint == endpoint
					
					retired << current if current
					backend = @backend_factory.call(endpoint, @exchange_limit, @permit_limit, self.method(:offer))
					@backends[endpoint.name] = backend
					started << backend
				end
			end
			
			retired.each(&:retire)
			started.each(&:start)
			notify_available unless retired.empty?
			
			self.size
		end
		
		# @returns [Array(Backend)] A snapshot of active backends.
		def backends
			@guard.synchronize{@backends.values.dup}
		end
		
		# Register the central scheduler capacity callback.
		def on_available(&block)
			@guard.synchronize{@available = block}
		end
		
		# @returns [Integer] The number of active endpoints.
		def size
			@guard.synchronize{@backends.size}
		end
		
		# @returns [Boolean] Whether no active endpoints are registered.
		def empty?
			self.size.zero?
		end
		
		# @returns [Array(String)] The active endpoint names.
		def names
			@guard.synchronize{@backends.keys.sort}
		end
		
		# Find an active backend by name.
		# @parameter name [String] The endpoint name.
		# @returns [Backend | Nil] The active backend.
		def [](name)
			@guard.synchronize{@backends[name.to_s]}
		end
		
		# Close the registry and retire all backends.
		def close
			backends = @guard.synchronize do
				next [] if @closed
				
				@closed = true
				@backends.values.tap{@backends = {}}
			end
			
			backends.each(&:retire)
		end
		
		protected
		
		def offer(_backend)
			notify_available
		end
		
		def notify_available
			available = @guard.synchronize{@available}
			available&.call
		end
		
		def make_backend(endpoint, exchange_limit, permit_limit, available)
			client = endpoint.make_client(exchange_limit: exchange_limit)
			Backend.new(endpoint, client, exchange_limit: exchange_limit, permit_limit: permit_limit, &available)
		end
	end
end
