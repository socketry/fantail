# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/queue"
require "protocol/http/response"

require_relative "configuration"

module Fantail
	# Matches pending requests to concrete backend permits.
	class Scheduler
		# A reserved processing permit and response exchange.
		class Reservation
			# @parameter backend [Backend] The reserved backend.
			# @parameter queue_name [Symbol] The queue consuming the permit.
			def initialize(backend, queue_name)
				@backend = backend
				@queue_name = queue_name
			end
			
			attr :backend
			
			# Release the processing permit after response headers arrive.
			def processed
				@backend.processed(@queue_name)
			end
			
			# Release the processing permit and exchange after an upstream failure.
			def failed
				@backend.failed(@queue_name)
			end
			
			# Release the response exchange after its body closes.
			def release
				@backend.release
			end
		end
		
		# A queue admission rejection.
		class Rejection
			# @parameter queue [Queue] The queue which rejected admission.
			def initialize(queue)
				@queue = queue
			end
			
			# @returns [Protocol::HTTP::Response] The configured shedding response.
			def response
				headers = {"content-type" => "text/plain"}.merge(@queue.shed_headers)
				Protocol::HTTP::Response[@queue.shed_status, headers, ["Request queue is full.\n"]]
			end
		end
		
		Entry = Struct.new(:request, :queue, :enqueued_at, :result, :pending, :assignment)
		
		# @parameter registry [Registry] The available backend registry.
		# @parameter configuration [Configuration] Request and scheduling policy.
		def initialize(registry, configuration = Configuration.default)
			@registry = registry
			@configuration = configuration
			@guard = Thread::Mutex.new
			@pending = configuration.queues.to_h{|name, queue| [name, []]}
			@pending_count = 0
			@closed = false
			
			@registry.on_available{schedule}
		end
		
		# Admit a request, wait for a matching permit, or return a rejection.
		def acquire(request)
			queue = @configuration.classify(request)
			entry = nil
			result = @guard.synchronize do
				if @closed
					nil
				elsif reservation = reserve(queue, request)
					reservation
				elsif @registry.empty?
					nil
				elsif reject?(queue, request)
					Rejection.new(queue)
				else
					entry = Entry.new(request, queue, now, Async::Queue.new, true, nil)
					@pending.fetch(queue.name) << entry
					@pending_count += 1
					schedule_locked
					entry.assignment
				end
			end
			
			return result unless entry
			
			if assignment = entry.assignment
				entry = nil
				return assignment
			end
			
			if wait_limit = queue.wait_limit
				remaining = wait_limit - (now - entry.enqueued_at)
				result = entry.result.dequeue(timeout: remaining) if remaining.positive?
				if result
					entry = nil
					return result
				end
				
				result = cancel(entry)
				entry = nil
				return result
			else
				result = entry.result.dequeue
				entry = nil
				return result
			end
		ensure
			if entry && assignment = cancel(entry, rejection: false)
				# The request was assigned concurrently but its waiting task was
				# interrupted before receiving the reservation. No upstream request
				# was started, so release both the permit and response exchange.
				assignment.failed
			end
		end
		
		# Try to dispatch pending requests after capacity changes.
		def schedule
			@guard.synchronize{schedule_locked unless @closed}
		end
		
		# Stop accepting requests and wake all tasks waiting for a permit.
		def close
			entries = @guard.synchronize do
				return if @closed
				
				@closed = true
				entries = @pending.values.flatten(1)
				@pending.each_value(&:clear)
				@pending_count = 0
				entries.each{|entry| entry.pending = false}
				entries
			end
			
			entries.each{|entry| entry.result.close}
		end
		
		# @parameter queue_name [Symbol | String | Nil] An optional queue to inspect.
		# @returns [Integer] The number of requests waiting for a permit.
		def pending_count(queue_name = nil)
			@guard.synchronize do
				if queue_name
					@pending.fetch(queue_name.to_sym).size
				else
					@pending_count
				end
			end
		end
		
		protected
		
		def now
			Process.clock_gettime(Process::CLOCK_MONOTONIC)
		end
		
		def reject?(queue, request)
			return true if @configuration.pending_limit && @pending_count >= @configuration.pending_limit
			pending = @pending.fetch(queue.name).size
			return true if queue.depth_limit && pending >= queue.depth_limit
			return true unless queue.admit?(request, pending: pending)
			
			false
		end
		
		def cancel(entry, rejection: true)
			@guard.synchronize do
				return entry.assignment unless entry.pending
				
				@pending.fetch(entry.queue.name).delete(entry)
				entry.pending = false
				@pending_count -= 1
				Rejection.new(entry.queue) if rejection
			end
		end
		
		def schedule_locked
			loop do
				entries = @pending.each_value.filter_map(&:first).sort_by(&:enqueued_at)
				matched = false
				
				entries.each do |entry|
					if reservation = reserve(entry.queue, entry.request)
						@pending.fetch(entry.queue.name).shift
						@pending_count -= 1
						entry.pending = false
						entry.assignment = reservation
						entry.result.enqueue(reservation)
						matched = true
						break
					end
				end
				
				break unless matched
			end
		end
		
		def reserve(queue, request)
			backends = @registry.backends.select do |backend|
				backend.available? && queue.eligible?(backend, request)
			end
			
			until backends.empty?
				backend = queue.balance_policy.select(backends, queue: queue, request: request)
				return nil unless backend
				raise ArgumentError, "Balance policy selected an ineligible backend!" unless backends.include?(backend)
				
				return Reservation.new(backend, queue.name) if backend.reserve(queue.name)
				backends.delete(backend)
			end
			
			nil
		end
	end
end
