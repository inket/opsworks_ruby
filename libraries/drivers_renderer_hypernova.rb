# frozen_string_literal: true

module Drivers
  module Renderer
    class Hypernova < Drivers::Renderer::Base
      def enabled?
        deploy_to = deploy_dir(app)
        release_path = Dir[File.join(deploy_to, 'releases', '*')].last
        return false unless release_path

        package_json_path = File.join(release_path, 'package.json')
        return false unless File.exist?(package_json_path)

        scripts = JSON.parse(File.read(package_json_path))['scripts']
        scripts.has_key?('hypernova:start')
      end

      def start_command
        "cd #{current_dir} && yarn hypernova:start > #{log_file} 2>&1 & echo $! > #{pid_file}"
      end

      def stop_command
        "pkill -TERM -g $(ps ax -o pgid= -q $(cat '#{pid_file}') | xargs)"
      end
    end
  end
end
