# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fantail/configuration"
require "protocol/http/request"
require "tmpdir"

describe Fantail::Configuration do
	let(:configuration) do
		subject.define do |config|
			config.queue :grpc do |queue|
				queue.match{|request| request.headers["content-type"]&.start_with?("application/grpc")}
				queue.balance :pack
			end
			
			config.queue :liquid do |queue|
				queue.balance :spread
				queue.depth_limit 500
				queue.wait_limit 0.25
				queue.shed status: 429, retry_after: 1
			end
			
			config.default_queue :liquid
			config.pending_limit 1_000
			config.permit_limit 2
		end
	end
	
	it "classifies requests and freezes the result" do
		grpc = Protocol::HTTP::Request["POST", "/rpc", {"content-type" => "application/grpc+proto"}]
		liquid = Protocol::HTTP::Request["GET", "/render"]
		
		expect(configuration.classify(grpc).name).to be == :grpc
		expect(configuration.classify(liquid).name).to be == :liquid
		expect(configuration.pending_limit).to be == 1_000
		expect(configuration.permit_limit).to be == 2
		expect(configuration).to be(:frozen?)
		expect(configuration.queues.fetch(:liquid)).to be(:frozen?)
	end
	
	it "loads trusted application configuration" do
		Dir.mktmpdir do |directory|
			path = File.join(directory, "fantail.rb")
			File.write(path, <<~RUBY)
				Fantail::Configuration.define do |config|
					config.queue :default
				end
			RUBY
			
			loaded = subject.load(path)
			expect(loaded.default_queue_name).to be == :default
		end
	end
	
	it "rejects configuration files with the wrong result" do
		Dir.mktmpdir do |directory|
			path = File.join(directory, "fantail.rb")
			File.write(path, "Object.new\n")
			
			expect{subject.load(path)}.to raise_exception(TypeError)
		end
	end
	
	it "rejects invalid balance policies" do
		expect do
			subject.define do |config|
				config.queue(:default){|queue| queue.balance Object.new}
			end
		end.to raise_exception(ArgumentError)
	end
end
