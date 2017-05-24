# frozen_string_literal: true

module Drivers
  module Renderer
    class Factory
      def self.build(context, app, options = {})
        engine = Drivers::Renderer::Base.descendants.detect(&:enabled?)
        raise StandardError, 'There is no supported Renderer driver for given configuration.' if engine.blank?
        engine.new(context, app, options)
      end
    end
  end
end
