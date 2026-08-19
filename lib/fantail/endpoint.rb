# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/client"
require "async/http/endpoint"
require "async/http/protocol/http1"
require "async/http/protocol/http2"

module Fantail
	# Represents a named HTTP backend endpoint.
	class Endpoint
		# Coerce an endpoint or endpoint description into an endpoint.
		# @parameter description [Endpoint | Hash] The endpoint or serialized endpoint description.
		# @returns [Endpoint] The coerced endpoint.
		def self.coerce(description)
			return description if description.is_a?(self)
			
			name = description[:name] || description["name"]
			url = description[:url] || description["url"]
			protocol = description[:protocol] || description["protocol"]
			
			self.new(name, url, protocol: protocol)
		end
		
		# Initialize a named backend endpoint.
		# @parameter name [String] The stable endpoint identity.
		# @parameter url [String] The absolute backend URL.
		# @parameter protocol [String | Nil] The upstream HTTP protocol name.
		def initialize(name, url, protocol: nil)
			raise ArgumentError, "Endpoint name is required!" unless name
			raise ArgumentError, "Endpoint URL is required!" unless url
			
			@name = name.to_s
			@url = url.to_s
			@protocol = protocol&.to_s
			
			freeze
		end
		
		# @attribute [String] The stable endpoint identity.
		attr :name
		
		# @attribute [String] The absolute backend URL.
		attr :url
		
		# @attribute [String | Nil] The upstream HTTP protocol name.
		attr :protocol
		
		# Build an HTTP client for this endpoint.
		# @parameter exchange_limit [Integer] The maximum number of outstanding response exchanges.
		# @returns [Async::HTTP::Client] A client connected to this endpoint.
		def make_client(exchange_limit:)
			endpoint = Async::HTTP::Endpoint.parse(@url, protocol: protocol_module)
			
			Async::HTTP::Client.new(endpoint, limit: exchange_limit, retries: 0)
		end
		
		# Convert this endpoint into a transport-safe description.
		# @returns [Hash] A serialized endpoint description.
		def to_h
			{
				"name" => @name,
				"url" => @url,
				"protocol" => @protocol,
			}.compact
		end
		
		# Compare endpoints by their serialized configuration.
		def ==(other)
			other.is_a?(Endpoint) && other.to_h == self.to_h
		end
		
		protected
		
		def protocol_module
			case @protocol
			when nil, "http/1.0", "http/1.1"
				Async::HTTP::Protocol::HTTP1
			when "h2", "http/2"
				Async::HTTP::Protocol::HTTP2
			else
				raise ArgumentError, "Unsupported HTTP protocol: #{@protocol.inspect}"
			end
		end
	end
end
