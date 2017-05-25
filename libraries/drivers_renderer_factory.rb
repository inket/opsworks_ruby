# frozen_string_literal: true

module Drivers
  module Renderer
    class Factory
      def self.build(context, app, options = {})
        Drivers::Renderer::Base.descendants.map do |renderer|
          renderer.new(context, app, options)
        end
      end
    end
  end
end
