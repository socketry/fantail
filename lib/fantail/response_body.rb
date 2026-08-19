# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/http/body/wrapper"

module Fantail
	# Wraps an upstream response body and releases its backend exchange when closed.
	class ResponseBody < Protocol::HTTP::Body::Wrapper
		# Initialize a response body wrapper.
		# @parameter body [Protocol::HTTP::Body::Readable] The upstream response body.
		# @yields Invoked exactly once when the response body closes.
		def initialize(body, &release)
			super(body)
			@release = release
		end
		
		# Close the upstream body and release its backend exchange.
		# @parameter error [Exception | Nil] The error which caused the body to close.
		def close(error = nil)
			super
		ensure
			if release = @release
				@release = nil
				release.call
			end
		end
	end
end
