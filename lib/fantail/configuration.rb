# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "balance"
require_relative "loader"

module Fantail
	# Immutable request queue and admission configuration.
	class Configuration
		UNDEFINED = Object.new.freeze
		
		# Configuration for one class of requests.
		class Queue
			# @parameter name [Symbol | String] The stable queue name.
			def initialize(name)
				@name = name.to_sym
				@matcher = nil
				@eligibility = nil
				@admission = nil
				@balance = Balance::Spread.new
				@depth_limit = nil
				@wait_limit = nil
				@shed_status = 429
				@shed_headers = {}
			end
			
			attr :name
			attr :balance_policy
			attr :shed_status
			attr :shed_headers
			
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
				@balance = Balance.coerce(policy, **options)
			end
			
			# Set or get the maximum number of requests waiting in this queue.
			# @parameter value [Integer] The new limit when given.
			# @returns [Integer | Nil] The configured limit.
			def depth_limit(value = UNDEFINED)
				return @depth_limit if value.equal?(UNDEFINED)
				
				value = Integer(value)
				raise ArgumentError, "Depth limit must not be negative!" if value.negative?
				@depth_limit = value
			end
			
			# Set or get the maximum time a request may wait for a permit.
			# @parameter value [Numeric] The new limit in seconds when given.
			# @returns [Float | Nil] The configured limit.
			def wait_limit(value = UNDEFINED)
				return @wait_limit if value.equal?(UNDEFINED)
				
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
			
			# Validate and freeze this queue definition.
			# @returns [Queue] The finalized queue.
			def finalize
				@balance_policy = @balance
				@shed_headers.freeze
				freeze
			end
		end
		
		# Build and finalize a configuration using a scoped loader.
		# @parameter root [String] The root for relative configuration files.
		# @yields {|loader| ...} The configuration loader.
		# @returns [Configuration] The immutable configuration.
		def self.build(root: Dir.pwd, &block)
			configuration = new
			loader = Loader.new(configuration, root)
			
			if block
				if block.arity.zero?
					loader.instance_eval(&block)
				else
					block.call(loader)
				end
			end
			
			configuration.finalize
		end
		
		# @returns [Configuration] A single-queue, single-permit configuration.
		def self.default
			@default ||= build do
				queue(:default)
				default_queue(:default)
			end
		end
		
		# Load and finalize trusted application configuration files.
		# @parameter paths [String | Array(String)] The configuration files to load.
		# @returns [Configuration] The immutable configuration.
		def self.load(paths)
			configuration = new
			Array(paths).each{|path| configuration.load_file(path)}
			configuration.finalize
		end
		
		# Initialize an empty mutable configuration builder.
		def initialize
			@queues = {}
			@default_queue = nil
			@pending_limit = nil
			@permit_limit = 1
		end
		
		attr :queues
		attr :default_queue_name
		
		# Load a trusted configuration file into this configuration.
		# @parameter path [String] The configuration file to load.
		def load_file(path)
			Loader.load_file(self, path)
		end
		
		# Define a named request queue. Matchers are evaluated in definition order.
		def queue(name)
			name = name.to_sym
			raise ArgumentError, "Queue #{name.inspect} is already defined!" if @queues.key?(name)
			
			queue = Queue.new(name)
			yield queue if block_given?
			@queues[name] = queue
			queue
		end
		
		# Select the fallback queue for unmatched requests.
		# @parameter name [Symbol | String] A previously or subsequently defined queue.
		def default_queue(name)
			@default_queue = name.to_sym
		end
		
		# Set or get the global pending request limit.
		def pending_limit(value = UNDEFINED)
			return @pending_limit if value.equal?(UNDEFINED)
			
			value = Integer(value)
			raise ArgumentError, "Pending limit must not be negative!" if value.negative?
			@pending_limit = value
		end
		
		# Set or get the number of processing permits provided by each worker.
		def permit_limit(value = UNDEFINED)
			return @permit_limit if value.equal?(UNDEFINED)
			
			value = Integer(value)
			raise ArgumentError, "Permit limit must be positive!" unless value.positive?
			@permit_limit = value
		end
		
		# Classify a request using matchers in definition order.
		# @returns [Queue] The matching or default queue.
		def classify(request)
			@queues.each_value do |queue|
				return queue if queue.match?(request)
			end
			
			@queues.fetch(@default_queue)
		end
		
		# Validate and freeze the complete configuration.
		# @returns [Configuration] The finalized configuration.
		def finalize
			raise ArgumentError, "At least one queue must be defined!" if @queues.empty?
			@default_queue ||= @queues.keys.first
			raise ArgumentError, "Default queue #{@default_queue.inspect} is not defined!" unless @queues.key?(@default_queue)
			
			@queues.each_value(&:finalize)
			@queues.freeze
			@default_queue_name = @default_queue
			freeze
		end
	end
end
