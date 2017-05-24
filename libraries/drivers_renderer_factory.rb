# frozen_string_literal: true

module Drivers
  module Renderer
    class Factory
      def self.build(context, app, options = {})
        engine = detect_engine(context, app, options)
        raise StandardError, 'There is no supported Renderer driver for given configuration.' if engine.blank?
        engine.new(context, app, options)
      end

      def self.detect_engine(context, app, options)
        Drivers::Renderer::Base.descendants.detect do |renderer_driver|
          renderer_driver.enabled?(context, app, options)
        end || Drivers::Renderer::Null
      end
    end
  end
end
