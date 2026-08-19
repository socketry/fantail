# frozen_string_literal: true

require_relative "lib/fantail/version"

Gem::Specification.new do |spec|
	spec.name = "fantail"
	spec.version = Fantail::VERSION
	
	spec.summary = "Worker-aware HTTP load balancing with a global admission queue."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/fantail"
	
	spec.metadata = {
		"bug_tracker_uri" => "https://github.com/socketry/fantail/issues",
		"changelog_uri" => "https://github.com/socketry/fantail/blob/main/releases.md",
		"documentation_uri" => "https://socketry.github.io/fantail/",
		"funding_uri" => "https://github.com/sponsors/ioquatix/",
		"source_code_uri" => "https://github.com/socketry/fantail.git",
	}
	
	spec.files = Dir.glob(["{lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.3"
	
	spec.add_dependency "async-bus", "~> 0.3"
	spec.add_dependency "async-http", "~> 0.99"
end
