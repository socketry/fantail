# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Fantail
	# Built-in backend selection policies.
	module Balance
		# Prefer the backend with the fewest active requests.
		class Spread
			def select(backends, queue:, request:)
				backends.min_by{|backend| [backend.processing, backend.name]}
			end
		end
		
		# Prefer a backend which is already processing the same class of work.
		class Pack
			def initialize(affinity: nil)
				@affinity = affinity
			end
			
			def select(backends, queue:, request:)
				affinity = @affinity || queue.name
				backends.min_by do |backend|
					[-backend.processing_for(affinity), backend.processing, backend.name]
				end
			end
		end
		
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
