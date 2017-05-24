# frozen_string_literal: true

module Drivers
  module Renderer
    class Hypernova < Drivers::Renderer::Base
      adapter :hypernova
      output filter: %i[process_count]
      packages :monit

      def self.enabled?(context, _app, _options)
        Chef::Log.info(context)
        Chef::Log.info(context.respond_to?(:release_path))
        return false
        package_json_path = File.join(release_path, 'package.json')
        return false unless File.exist?(package_json_path)

        scripts = JSON.parse(File.read(package_json_path))['scripts']
        scripts.has_key?('hypernova')
      end

      def configure
        add_worker_monit
      end

      def after_deploy
        restart_monit
      end

      def shutdown
        stop_monit
      end

      alias after_undeploy after_deploy
    end
  end
end
