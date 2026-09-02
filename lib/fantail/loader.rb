# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Fantail
	# The domain-specific language for building and loading configuration.
	class Loader
		# Initialize a loader attached to a configuration.
		# @parameter configuration [Configuration] The configuration being built.
		# @parameter root [String | Nil] The root for relative configuration files.
		def initialize(configuration, root = nil)
			@configuration = configuration
			@root = root
		end
		
		# @attribute [String | Nil] The root for relative configuration files.
		attr :root
		
		# Evaluate a configuration file using a scoped loader.
		# @parameter configuration [Configuration] The configuration being built.
		# @parameter path [String] The configuration file to load.
		def self.load_file(configuration, path)
			realpath = File.realpath(path)
			loader = new(configuration, File.dirname(realpath))
			
			if Module.method_defined?(:set_temporary_name)
				loader.singleton_class.set_temporary_name("#{self}[#{path.inspect}]")
			end
			
			loader.instance_eval(File.read(realpath), realpath)
		end
		
		# Load another configuration file relative to this loader.
		# @parameter path [String] The relative or absolute configuration path.
		def load_file(path)
			self.class.load_file(@configuration, File.expand_path(path, @root))
		end
		
		# Define a named request queue.
		# @parameter name [Symbol | String] The stable queue name.
		# @yields {|queue| ...} The queue configuration, or evaluates the block as its DSL.
		def queue(name, &block)
			return @configuration.queue(name) unless block
			
			@configuration.queue(name) do |queue|
				if block.arity.zero?
					queue.instance_eval(&block)
				else
					block.call(queue)
				end
			end
		end
		
		# Select the fallback queue for unmatched requests.
		# @parameter name [Symbol | String] A defined queue name.
		def default_queue(name)
			@configuration.default_queue(name)
		end
		
		# Set the global pending request limit.
		# @parameter value [Integer] The maximum number of pending requests.
		def pending_limit(value)
			@configuration.pending_limit(value)
		end
		
		# Set the number of processing permits provided by each worker.
		# @parameter value [Integer] The number of permits per worker.
		def permit_limit(value)
			@configuration.permit_limit(value)
		end
	end
end
