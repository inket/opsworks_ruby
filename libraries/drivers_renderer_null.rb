# frozen_string_literal: true

module Drivers
  module Renderer
    class Null < Drivers::Renderer::Base
      adapter :null
      output filter: []
    end
  end
end
