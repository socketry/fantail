# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "fantail/version"
require_relative "fantail/endpoint"
require_relative "fantail/backend"
require_relative "fantail/response_body"
require_relative "fantail/registry"
require_relative "fantail/proxy"
require_relative "fantail/control"
require_relative "fantail/monitor"
require_relative "fantail/server"

# Provides worker-aware HTTP load balancing with a global admission queue.
module Fantail
end
