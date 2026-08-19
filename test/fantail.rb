# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fantail"

describe Fantail do
	it "has a version number" do
		expect(Fantail::VERSION).to be =~ /\d+\.\d+\.\d+/
	end
end
