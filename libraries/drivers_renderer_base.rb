# frozen_string_literal: true

require_relative "drivers_worker_base"

module Drivers
  module Renderer
    class Base < Drivers::Worker::Base
      def self.enabled?(_, _, _)
        false
      end
    end
  end
end
