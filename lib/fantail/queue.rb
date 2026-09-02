# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "balance"

module Fantail
	# Immutable policy for one class of requests.
	class Queue
		# Builds a queue policy using the configuration DSL.
		class Builder
			# @parameter name [Symbol | String] The stable queue name.
			def initialize(name)
				@name = name
				@matcher = nil
				@eligibility = nil
				@admission = nil
				@balance_policy = Balance::Spread.new
				@depth_limit = nil
				@wait_limit = nil
				@shed_status = 429
				@shed_headers = {}
			end
			
			# Set the request classifier for this queue.
			# @yields {|request| ...} Whether a request belongs to this queue.
			def match(&block)
				raise ArgumentError, "A matcher block is required!" unless block
				@matcher = block
			end
			
			# Restrict the backends which may serve this queue.
			# @yields {|backend, request| ...} Whether the backend is eligible.
			def eligible(&block)
				raise ArgumentError, "An eligibility block is required!" unless block
				@eligibility = block
			end
			
			# Set an application admission policy.
			# @parameter policy [#admit? | #call | Nil] The admission policy object.
			# @yields {|request, queue:, pending:| ...} Whether the request can wait.
			def admit(policy = nil, &block)
				@admission = policy || block
				raise ArgumentError, "An admission policy is required!" unless @admission
			end
			
			# Set the soft backend balance policy.
			# @parameter policy [Symbol | #select] A built-in name or application policy.
			# @parameter options [Hash] Options for a built-in policy.
			def balance(policy, **options)
				@balance_policy = Balance.coerce(policy, **options)
			end
			
			# Set the maximum number of requests waiting in this queue.
			# @parameter value [Integer] The maximum queue depth.
			def depth_limit(value)
				value = Integer(value)
				raise ArgumentError, "Depth limit must not be negative!" if value.negative?
				@depth_limit = value
			end
			
			# Set the maximum time a request may wait for a permit.
			# @parameter value [Numeric] The maximum wait in seconds.
			def wait_limit(value)
				value = Float(value)
				raise ArgumentError, "Wait limit must be positive!" unless value.positive?
				@wait_limit = value
			end
			
			# Configure the response used when admission is rejected.
			# @parameter status [Integer] The HTTP response status.
			# @parameter retry_after [Numeric | String | Nil] An optional Retry-After value.
			# @parameter headers [Hash] Additional response headers.
			def shed(status: 429, retry_after: nil, headers: {})
				@shed_status = Integer(status)
				@shed_headers = headers.transform_keys(&:to_s)
				@shed_headers["retry-after"] = retry_after.to_s if retry_after
			end
			
			# Build the immutable queue policy.
			# @returns [Queue] The configured queue.
			def build
				Queue.new(
					@name,
					matcher: @matcher,
					eligibility: @eligibility,
					admission: @admission,
					balance_policy: @balance_policy,
					depth_limit: @depth_limit,
					wait_limit: @wait_limit,
					shed_status: @shed_status,
					shed_headers: @shed_headers,
				)
			end
		end
		
		# @parameter name [Symbol | String] The stable queue name.
		# @parameter matcher [Proc | Nil] The request classifier.
		# @parameter eligibility [Proc | Nil] The backend eligibility policy.
		# @parameter admission [#admit? | #call | Nil] The queue admission policy.
		# @parameter balance_policy [#select] The backend balance policy.
		# @parameter depth_limit [Integer | Nil] The maximum queue depth.
		# @parameter wait_limit [Float | Nil] The maximum queue wait.
		# @parameter shed_status [Integer] The rejection response status.
		# @parameter shed_headers [Hash] The rejection response headers.
		def initialize(name, matcher:, eligibility:, admission:, balance_policy:, depth_limit:, wait_limit:, shed_status:, shed_headers:)
			@name = name.to_sym
			@matcher = matcher
			@eligibility = eligibility
			@admission = admission
			@balance_policy = balance_policy
			@depth_limit = depth_limit
			@wait_limit = wait_limit
			@shed_status = shed_status
			@shed_headers = shed_headers.freeze
			freeze
		end
		
		attr :name
		attr :balance_policy
		attr :depth_limit
		attr :wait_limit
		attr :shed_status
		attr :shed_headers
		
		# @parameter request [Protocol::HTTP::Request] The request to classify.
		# @returns [Boolean | Nil] Whether the request matches this queue.
		def match?(request)
			@matcher&.call(request)
		end
		
		# @returns [Boolean] Whether a backend may serve the request.
		def eligible?(backend, request)
			!@eligibility || @eligibility.call(backend, request)
		end
		
		# @returns [Boolean] Whether a request may enter the pending queue.
		def admit?(request, pending:)
			return true unless @admission
			
			if @admission.respond_to?(:admit?)
				@admission.admit?(request, queue: self, pending: pending)
			else
				@admission.call(request, queue: self, pending: pending)
			end
		end
	end
end
