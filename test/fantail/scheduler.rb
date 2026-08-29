# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fantail"
require "sus/fixtures/async/reactor_context"
require_relative "fixtures"

describe Fantail::Scheduler do
	include Sus::Fixtures::Async::ReactorContext
	include Fantail::Fixtures
	
	def make_configuration(permit_limit: 1, pending_limit: nil, &block)
		Fantail::Configuration.define do |configuration|
			configuration.permit_limit permit_limit
			configuration.pending_limit pending_limit if pending_limit
			block.call(configuration)
		end
	end
	
	def add_workers(registry, count = 2)
		registry.replace(Array.new(count) do |index|
			{name: "worker-#{index + 1}", url: "http://127.0.0.1:#{9301 + index}"}
		end)
	end
	
	def finish(reservation)
		reservation.processed
		reservation.release
	end
	
	it "spreads work across workers with spare permits" do
		configuration = make_configuration(permit_limit: 2) do |config|
			config.queue(:liquid){|queue| queue.balance :spread}
		end
		registry = make_registry(permit_limit: configuration.permit_limit)
		add_workers(registry)
		scheduler = subject.new(registry, configuration)
		
		first = scheduler.acquire(Protocol::HTTP::Request["GET", "/first"])
		second = scheduler.acquire(Protocol::HTTP::Request["GET", "/second"])
		
		expect([first.backend.name, second.backend.name]).to be == ["worker-1", "worker-2"]
	ensure
		finish(first) if first
		finish(second) if second
		registry&.close
	end
	
	it "packs affinity work onto an active worker" do
		configuration = make_configuration(permit_limit: 2) do |config|
			config.queue(:grpc){|queue| queue.balance :pack, affinity: :grpc}
		end
		registry = make_registry(permit_limit: configuration.permit_limit)
		add_workers(registry)
		scheduler = subject.new(registry, configuration)
		
		first = scheduler.acquire(Protocol::HTTP::Request["POST", "/first"])
		second = scheduler.acquire(Protocol::HTTP::Request["POST", "/second"])
		
		expect([first.backend.name, second.backend.name]).to be == ["worker-1", "worker-1"]
	ensure
		finish(first) if first
		finish(second) if second
		registry&.close
	end
	
	it "keeps affinity work-conserving" do
		configuration = make_configuration(permit_limit: 2) do |config|
			config.queue(:grpc){|queue| queue.balance :pack}
		end
		registry = make_registry(permit_limit: configuration.permit_limit)
		add_workers(registry)
		scheduler = subject.new(registry, configuration)
		
		first = scheduler.acquire(Protocol::HTTP::Request["POST", "/first"])
		second = scheduler.acquire(Protocol::HTTP::Request["POST", "/second"])
		third = scheduler.acquire(Protocol::HTTP::Request["POST", "/third"])
		
		expect([first.backend.name, second.backend.name, third.backend.name]).to be == ["worker-1", "worker-1", "worker-2"]
	ensure
		finish(first) if first
		finish(second) if second
		finish(third) if third
		registry&.close
	end
	
	it "supports application balance policies" do
		policy = Object.new
		policy.define_singleton_method(:select){|backends, **| backends.last}
		configuration = make_configuration do |config|
			config.queue(:default){|queue| queue.balance policy}
		end
		registry = make_registry
		add_workers(registry)
		scheduler = subject.new(registry, configuration)
		
		reservation = scheduler.acquire(Protocol::HTTP::Request["GET", "/"])
		expect(reservation.backend.name).to be == "worker-2"
	ensure
		finish(reservation) if reservation
		registry&.close
	end
	
	it "uses another queue when the oldest queue has no eligible worker" do
		configuration = make_configuration do |config|
			config.queue :special do |queue|
				queue.match{|request| request.path == "/special"}
				queue.eligible{|backend, _request| backend.name == "special-worker"}
			end
			config.queue :default
			config.default_queue :default
		end
		registry = make_registry
		registry.replace([{name: "default-worker", url: "http://127.0.0.1:9301"}])
		scheduler = subject.new(registry, configuration)
		held = scheduler.acquire(Protocol::HTTP::Request["GET", "/held"])
		
		special_task = Async{scheduler.acquire(Protocol::HTTP::Request["GET", "/special"])}
		Fiber.scheduler.yield
		default_task = Async{scheduler.acquire(Protocol::HTTP::Request["GET", "/default"])}
		Fiber.scheduler.yield
		
		finish(held)
		held = nil
		default = default_task.wait
		expect(default.backend.name).to be == "default-worker"
		expect(special_task).not.to be(:finished?)
	ensure
		finish(held) if held
		finish(default) if default
		special_task&.stop
		default_task&.stop
		registry&.close
	end
	
	it "dispatches the oldest eligible queue head first" do
		configuration = make_configuration do |config|
			config.queue(:alpha){|queue| queue.match{|request| request.path == "/alpha"}}
			config.queue :beta
			config.default_queue :beta
		end
		registry = make_registry
		add_workers(registry, 1)
		scheduler = subject.new(registry, configuration)
		held = scheduler.acquire(Protocol::HTTP::Request["GET", "/held"])
		
		alpha_task = Async{scheduler.acquire(Protocol::HTTP::Request["GET", "/alpha"])}
		Fiber.scheduler.yield
		beta_task = Async{scheduler.acquire(Protocol::HTTP::Request["GET", "/beta"])}
		Fiber.scheduler.yield
		
		finish(held)
		held = nil
		alpha = alpha_task.wait
		expect(beta_task).not.to be(:finished?)
		finish(alpha)
		alpha = nil
		beta = beta_task.wait
		expect(beta.backend.name).to be == "worker-1"
	ensure
		finish(held) if held
		finish(alpha) if alpha
		finish(beta) if beta
		alpha_task&.stop
		beta_task&.stop
		registry&.close
	end
	
	it "sheds requests when the queue depth limit is reached" do
		configuration = make_configuration do |config|
			config.queue :default do |queue|
				queue.depth_limit 1
				queue.shed status: 429, retry_after: 2
			end
		end
		registry = make_registry
		add_workers(registry, 1)
		scheduler = subject.new(registry, configuration)
		held = scheduler.acquire(Protocol::HTTP::Request["GET", "/held"])
		waiting_task = Async{scheduler.acquire(Protocol::HTTP::Request["GET", "/waiting"])}
		Fiber.scheduler.yield
		
		rejection = scheduler.acquire(Protocol::HTTP::Request["GET", "/rejected"])
		response = rejection.response
		
		expect(response.status).to be == 429
		expect(response.headers["retry-after"]).to be == "2"
	ensure
		response&.close
		finish(held) if held
		waiting = waiting_task&.wait
		finish(waiting) if waiting
		waiting_task&.stop
		registry&.close
	end
	
	it "sheds requests which exceed their queue wait limit" do
		configuration = make_configuration do |config|
			config.queue(:default){|queue| queue.wait_limit 0.01}
		end
		registry = make_registry
		add_workers(registry, 1)
		scheduler = subject.new(registry, configuration)
		held = scheduler.acquire(Protocol::HTTP::Request["GET", "/held"])
		
		rejection = scheduler.acquire(Protocol::HTTP::Request["GET", "/waiting"])
		expect(rejection).to be_a(Fantail::Scheduler::Rejection)
		expect(scheduler.pending_count).to be == 0
	ensure
		finish(held) if held
		registry&.close
	end
	
	it "supports application admission policies" do
		configuration = make_configuration do |config|
			config.queue(:default){|queue| queue.admit{|request, **| request.path != "/shed"}}
		end
		registry = make_registry
		add_workers(registry, 1)
		scheduler = subject.new(registry, configuration)
		held = scheduler.acquire(Protocol::HTTP::Request["GET", "/held"])
		
		rejection = scheduler.acquire(Protocol::HTTP::Request["GET", "/shed"])
		expect(rejection).to be_a(Fantail::Scheduler::Rejection)
	ensure
		finish(held) if held
		registry&.close
	end
end
