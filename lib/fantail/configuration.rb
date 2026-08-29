# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "balance"

module Fantail
	# Immutable request queue and admission configuration.
	class Configuration
		UNDEFINED = Object.new.freeze
		
		# Configuration for one class of requests.
		class Queue
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
			
			def match(&block)
				raise ArgumentError, "A matcher block is required!" unless block
				@matcher = block
			end
			
			def eligible(&block)
				raise ArgumentError, "An eligibility block is required!" unless block
				@eligibility = block
			end
			
			def admit(policy = nil, &block)
				@admission = policy || block
				raise ArgumentError, "An admission policy is required!" unless @admission
			end
			
			def balance(policy, **options)
				@balance = Balance.coerce(policy, **options)
			end
			
			def depth_limit(value = UNDEFINED)
				return @depth_limit if value.equal?(UNDEFINED)
				
				value = Integer(value)
				raise ArgumentError, "Depth limit must not be negative!" if value.negative?
				@depth_limit = value
			end
			
			def wait_limit(value = UNDEFINED)
				return @wait_limit if value.equal?(UNDEFINED)
				
				value = Float(value)
				raise ArgumentError, "Wait limit must be positive!" unless value.positive?
				@wait_limit = value
			end
			
			def shed(status: 429, retry_after: nil, headers: {})
				@shed_status = Integer(status)
				@shed_headers = headers.transform_keys(&:to_s)
				@shed_headers["retry-after"] = retry_after.to_s if retry_after
			end
			
			def match?(request)
				@matcher&.call(request)
			end
			
			def eligible?(backend, request)
				!@eligibility || @eligibility.call(backend, request)
			end
			
			def admit?(request, pending:)
				return true unless @admission
				
				if @admission.respond_to?(:admit?)
					@admission.admit?(request, queue: self, pending: pending)
				else
					@admission.call(request, queue: self, pending: pending)
				end
			end
			
			def finalize
				@balance_policy = @balance
				@shed_headers.freeze
				freeze
			end
		end
		
		def self.define
			configuration = new
			yield configuration if block_given?
			configuration.finalize
		end
		
		def self.default
			@default ||= define do |configuration|
				configuration.queue(:default)
				configuration.default_queue(:default)
			end
		end
		
		# Load trusted application configuration. The final expression must be a Configuration.
		def self.load(path)
			path = File.expand_path(path)
			configuration = TOPLEVEL_BINDING.eval(File.read(path), path)
			
			unless configuration.is_a?(self)
				raise TypeError, "#{path} must return a Fantail::Configuration!"
			end
			
			configuration
		end
		
		def initialize
			@queues = {}
			@default_queue = nil
			@pending_limit = nil
			@permit_limit = 1
		end
		
		attr :queues
		attr :default_queue_name
		
		# Define a named request queue. Matchers are evaluated in definition order.
		def queue(name)
			name = name.to_sym
			raise ArgumentError, "Queue #{name.inspect} is already defined!" if @queues.key?(name)
			
			queue = Queue.new(name)
			yield queue if block_given?
			@queues[name] = queue
			queue
		end
		
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
		
		def classify(request)
			@queues.each_value do |queue|
				return queue if queue.match?(request)
			end
			
			@queues.fetch(@default_queue)
		end
		
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
