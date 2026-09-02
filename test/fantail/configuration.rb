# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fantail/configuration"
require "protocol/http/request"
require "tmpdir"

describe Fantail::Configuration do
	let(:configuration) do
		subject.build do
			queue :grpc do
				match {|request| request.headers["content-type"]&.start_with?("application/grpc")}
				balance :pack
			end
			
			queue :liquid do
				balance :spread
				depth_limit 500
				wait_limit 0.25
				shed status: 429, retry_after: 1
			end
			
			default_queue :liquid
			pending_limit 1_000
			permit_limit 2
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
			File.write(path, "queue :default\n")
			
			loaded = subject.load(path)
			expect(loaded.default_queue_name).to be == :default
		end
	end
	
	it "loads configuration files relative to the current file" do
		Dir.mktmpdir do |directory|
			queues_path = File.join(directory, "queues.rb")
			path = File.join(directory, "fantail.rb")
			File.write(queues_path, "queue :default\n")
			File.write(path, "load_file 'queues.rb'\n")
			
			loaded = subject.load(path)
			expect(loaded.default_queue_name).to be == :default
		end
	end
	
	it "builds configuration with an explicit loader" do
		configuration = subject.build do |loader|
			loader.queue(:default)
		end
		
		expect(configuration.default_queue_name).to be == :default
	end
	
	it "rejects invalid balance policies" do
		expect do
			subject.build do |config|
				config.queue(:default){|queue| queue.balance Object.new}
			end
		end.to raise_exception(ArgumentError)
	end
end
