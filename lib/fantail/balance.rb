# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Fantail
	# Built-in backend selection policies.
	module Balance
		# Prefer the backend with the fewest active requests.
		class Spread
			# Select the least-active backend, using its name for deterministic ties.
			# @parameter backends [Array(Backend)] Eligible backends with available permits.
			# @parameter queue [Configuration::Queue] The request queue being scheduled.
			# @parameter request [Protocol::HTTP::Request] The pending request.
			# @returns [Backend | Nil] The preferred backend.
			def select(backends, queue:, request:)
				backends.min_by{|backend| [backend.processing, backend.name]}
			end
		end
		
		# Prefer a backend which is already processing the same class of work.
		class Pack
			# @parameter affinity [Symbol | Nil] The queue affinity to pack, or the current queue by default.
			def initialize(affinity: nil)
				@affinity = affinity
			end
			
			# Select the backend with the most active work for the affinity.
			# @parameter backends [Array(Backend)] Eligible backends with available permits.
			# @parameter queue [Configuration::Queue] The request queue being scheduled.
			# @parameter request [Protocol::HTTP::Request] The pending request.
			# @returns [Backend | Nil] The preferred backend.
			def select(backends, queue:, request:)
				affinity = @affinity || queue.name
				backends.min_by do |backend|
					[-backend.processing_for(affinity), backend.processing, backend.name]
				end
			end
		end
		
		# Resolve a built-in policy name or validate an application policy object.
		# @parameter policy [Symbol | #select] The policy name or object.
		# @parameter options [Hash] Options for a built-in policy.
		# @returns [#select] The resolved balance policy.
		def self.coerce(policy, **options)
			case policy
			when :spread
				Spread.new(**options)
			when :pack
				Pack.new(**options)
			else
				unless policy.respond_to?(:select)
					raise ArgumentError, "Balance policy must respond to #select!"
				end
				
				policy
			end
		end
	end
end
