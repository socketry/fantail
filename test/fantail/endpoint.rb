# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fantail/endpoint"

describe Fantail::Endpoint do
	it "can be serialized and coerced" do
		endpoint = subject.new("worker-1", "http://127.0.0.1:9293", protocol: "h2")
		
		expect(subject.coerce(endpoint.to_h)).to be == endpoint
	end
	
	it "requires a name and URL" do
		expect do
			subject.new(nil, "http://127.0.0.1:9293")
		end.to raise_exception(ArgumentError)
		
		expect do
			subject.new("worker-1", nil)
		end.to raise_exception(ArgumentError)
	end
	
	it "rejects unsupported protocols when constructing a client" do
		endpoint = subject.new("worker-1", "http://127.0.0.1:9293", protocol: "smtp")
		
		expect do
			endpoint.make_client(exchange_limit: 1)
		end.to raise_exception(ArgumentError, message: be =~ /Unsupported HTTP protocol/)
	end
	
	it "constructs an HTTP/2 client" do
		endpoint = subject.new("worker-1", "http://127.0.0.1:9293", protocol: "h2")
		client = endpoint.make_client(exchange_limit: 1)
		
		expect(client.protocol).to be == Async::HTTP::Protocol::HTTP2
	ensure
		client&.close
	end
end
