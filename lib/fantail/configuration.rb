# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "queue"

module Fantail
	# Immutable request queue and admission configuration.
	class Configuration
		# Builds configurations using the application DSL.
		class Builder
			# @parameter root [String] The root for relative configuration files.
			def initialize(root = Dir.pwd)
				@root = File.expand_path(root)
				@queues = {}
				@default_queue_name = nil
				@pending_limit = nil
				@permit_limit = 1
			end
			
			# @attribute [String] The root for relative configuration files.
			attr :root
			
			# Evaluate a trusted configuration file using this builder.
			# @parameter path [String] The relative or absolute configuration path.
			def load_file(path)
				realpath = File.realpath(File.expand_path(path, @root))
				root = @root
				@root = File.dirname(realpath)
				instance_eval(File.read(realpath), realpath)
			ensure
				@root = root if root
			end
			
			# Define a named request queue. Matchers are evaluated in definition order.
			# @parameter name [Symbol | String] The stable queue name.
			# @yields {|queue| ...} The queue builder, or evaluates the block as its DSL.
			# @returns [Queue] The configured queue.
			def queue(name, &block)
				name = name.to_sym
				raise ArgumentError, "Queue #{name.inspect} is already defined!" if @queues.key?(name)
				
				builder = Queue::Builder.new(name)
				if block
					if block.arity.zero?
						builder.instance_eval(&block)
					else
						block.call(builder)
					end
				end
				
				@queues[name] = builder.build
			end
			
			# Select the fallback queue for unmatched requests.
			# @parameter name [Symbol | String] A defined queue name.
			def default_queue(name)
				@default_queue_name = name.to_sym
			end
			
			# Set the global pending request limit.
			# @parameter value [Integer] The maximum number of pending requests.
			def pending_limit(value)
				value = Integer(value)
				raise ArgumentError, "Pending limit must not be negative!" if value.negative?
				@pending_limit = value
			end
			
			# Set the number of processing permits provided by each worker.
			# @parameter value [Integer] The number of permits per worker.
			def permit_limit(value)
				value = Integer(value)
				raise ArgumentError, "Permit limit must be positive!" unless value.positive?
				@permit_limit = value
			end
			
			# Validate and build the immutable configuration.
			# @returns [Configuration] The configured request queues.
			def build
				raise ArgumentError, "At least one queue must be defined!" if @queues.empty?
				default_queue_name = @default_queue_name || @queues.keys.first
				raise ArgumentError, "Default queue #{default_queue_name.inspect} is not defined!" unless @queues.key?(default_queue_name)
				
				Configuration.new(
					queues: @queues,
					default_queue_name: default_queue_name,
					pending_limit: @pending_limit,
					permit_limit: @permit_limit,
				)
			end
		end
		
		# Build a configuration using a scoped builder.
		# @parameter root [String] The root for relative configuration files.
		# @yields {|builder| ...} The configuration builder.
		# @returns [Configuration] The immutable configuration.
		def self.build(root: Dir.pwd, &block)
			builder = Builder.new(root)
			
			if block
				if block.arity.zero?
					builder.instance_eval(&block)
				else
					block.call(builder)
				end
			end
			
			builder.build
		end
		
		# @returns [Configuration] A single-queue, single-permit configuration.
		def self.default
			@default ||= build do
				queue(:default)
				default_queue(:default)
			end
		end
		
		# Load and build trusted application configuration files.
		# @parameter paths [String | Array(String)] The configuration files to load.
		# @returns [Configuration] The immutable configuration.
		def self.load(paths)
			builder = Builder.new
			Array(paths).each{|path| builder.load_file(path)}
			builder.build
		end
		
		# @parameter queues [Hash(Symbol, Queue)] The configured queues.
		# @parameter default_queue_name [Symbol] The fallback queue name.
		# @parameter pending_limit [Integer | Nil] The global pending request limit.
		# @parameter permit_limit [Integer] The processing permits per worker.
		def initialize(queues:, default_queue_name:, pending_limit:, permit_limit:)
			@queues = queues.dup.freeze
			@default_queue_name = default_queue_name
			@pending_limit = pending_limit
			@permit_limit = permit_limit
			freeze
		end
		
		attr :queues
		attr :default_queue_name
		attr :pending_limit
		attr :permit_limit
		
		# Classify a request using matchers in definition order.
		# @returns [Queue] The matching or default queue.
		def classify(request)
			@queues.each_value do |queue|
				return queue if queue.match?(request)
			end
			
			@queues.fetch(@default_queue_name)
		end
	end
end
