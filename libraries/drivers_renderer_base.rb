# frozen_string_literal: true

require_relative "drivers_worker_base"

module Drivers
  module Renderer
    class Base < Drivers::Base
      def name
        self.class.to_s.split("::").last.downcase
      end

      def current_dir
        File.join(deploy_dir(app), 'current')
      end

      def log_file
        "#{deploy_dir(app)}/shared/log/#{name}.log"
      end

      def pid_file
        "#{deploy_dir(app)}/shared/pids/#{name}.pid"
      end

      def enabled?
        false
      end

      def validate_app_engine; end

      def after_deploy
        # Chef sucks
        params = { name: name, pid_file: pid_file,
                   start_command: start_command, stop_command: stop_command }

        context.execute "stop #{params[:name]}" do
          command params[:stop_command]
          only_if {
            File.exist?(params[:pid_file]) &&
            system("/bin/ps -q $(cat '#{params[:pid_file]}') > /dev/null 2>&1")
          }
        end

        return unless enabled?

        context.execute "start #{params[:name]}" do
          command params[:start_command]
        end

        check_status
      end
      alias after_undeploy after_deploy

      def start_command
        'echo "Please overwrite start_command and stop_command to define a renderer" && false'
      end

      def stop_command
        'echo "Please overwrite start_command and stop_command to define a renderer" && false'
      end

      def check_status
        params = { name: name, log_file: log_file, pid_file: pid_file }

        context.ruby_block 'check_status' do
          block do
            begin
              command = "/bin/sleep 5 && /bin/ps -q $(cat #{params[:pid_file]})"

              r = Chef::Resource::Execute.new(command, run_context)
              r.command command
              r.retries 3
              r.returns 0
              r.run_action(:run)
            rescue StandardError => e
              Chef::Log.fatal("Could not start #{params[:name]} correctly.")
              Chef::Log.info("Printing #{params[:log_file]}…")
              Chef::Log.info(File.exist?(params[:log_file]) ? File.read(params[:log_file]) : '(does not exist)')
              raise e
            end
          end
        end
      end
    end
  end
end
