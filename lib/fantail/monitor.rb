# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/bus/client"
require "async/queue"

require_relative "endpoint"

module Fantail
	# Publishes a desired endpoint set and subsequent deltas to a Fantail registry.
	class Monitor < Async::Bus::Client
		# Initialize an endpoint monitor.
		# @parameter endpoint [IO::Endpoint] The Fantail control endpoint.
		def initialize(endpoint)
			super(endpoint)
			
			@guard = Thread::Mutex.new
			@endpoints = {}
			@revision = 0
			@changes = Async::Queue.new
		end
		
		# Replace the desired endpoint set without blocking on the control connection.
		# @parameter descriptions [Array(Endpoint | Hash)] The complete desired endpoint set.
		# @returns [Integer] The local revision number.
		def replace(descriptions)
			endpoints = descriptions.map{|description| Endpoint.coerce(description).to_h}
			
			revision = @guard.synchronize do
				@endpoints = endpoints.to_h{|description| [description.fetch("name"), description]}
				@revision += 1
			end
			
			@changes.enqueue([revision, :replace, endpoints])
			return revision
		end
		
		# Add or replace a desired endpoint without blocking on the control connection.
		# @parameter description [Endpoint | Hash] The endpoint to publish.
		# @returns [Integer] The local revision number.
		def upsert(description)
			endpoint = Endpoint.coerce(description).to_h
			
			revision = @guard.synchronize do
				@endpoints[endpoint.fetch("name")] = endpoint
				@revision += 1
			end
			
			@changes.enqueue([revision, :update, [endpoint], []])
			return revision
		end
		
		# Remove a desired endpoint without blocking on the control connection.
		# @parameter name [String] The endpoint identity to remove.
		# @returns [Integer] The local revision number.
		def remove(name)
			name = name.to_s
			
			revision = @guard.synchronize do
				@endpoints.delete(name)
				@revision += 1
			end
			
			@changes.enqueue([revision, :update, [], [name]])
			return revision
		end
		
		# @returns [Array(Hash)] A snapshot of the desired endpoints.
		def endpoints
			@guard.synchronize{@endpoints.values.map(&:dup)}
		end
		
		# Run the persistent publisher, resynchronizing completely after each reconnect.
		# @parameter options [Hash] Options forwarded to Async::Bus::Client#run.
		# @returns [Async::Task] The publisher task.
		def run(**options)
			super(**options) do |connection|
				synchronize(connection[:registry])
			end
		end
		
		protected
		
		def synchronize(registry)
			revision, endpoints = snapshot
			registry.replace(endpoints)
			
			publish_changes(registry, revision)
		end
		
		def snapshot
			@guard.synchronize{[@revision, @endpoints.values.map(&:dup)]}
		end
		
		def publish_changes(registry, revision)
			while change = @changes.dequeue
				change_revision, operation, *arguments = change
				next if change_revision <= revision
				
				registry.public_send(operation, *arguments)
				revision = change_revision
			end
		end
	end
end
