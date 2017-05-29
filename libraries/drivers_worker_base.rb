# frozen_string_literal: true

module Drivers
  module Worker
    class Base < Drivers::Base
      include Drivers::Dsl::Output
      include Drivers::Dsl::Packages

      def setup
        handle_packages
      end

      def out
        handle_output(raw_out)
      end

      def raw_out
        node['defaults']['worker'].merge(
          node['deploy'][app['shortname']]['worker'] || {}
        ).symbolize_keys
      end

      def validate_app_engine; end

      protected

      def add_worker_monit
        opts = { application: app['shortname'], out: out, deploy_to: deploy_dir(app), environment: environment,
                 adapter: adapter }

        context.template File.join(node['monit']['basedir'], "00_httpd.monitrc") do
          mode '0640'
          source "00_httpd.monitrc.erb"
          variables opts
        end

        context.template File.join(node['monit']['basedir'], "#{opts[:adapter]}_#{opts[:application]}.monitrc") do
          mode '0640'
          source "#{opts[:adapter]}.monitrc.erb"
          variables opts
        end

        context.execute 'monit reload'
      end

      def restart_monit
        (1..process_count).each do |process_number|
          context.execute "monit restart #{adapter}_#{app['shortname']}-#{process_number}" do
            retries 3
          end
        end

        check_status
      end

      def unmonitor_monit
        (1..process_count).each do |process_number|
          context.execute "monit unmonitor #{adapter}_#{app['shortname']}-#{process_number}" do
            retries 3
          end
        end
      end

      def stop_monit
        (1..process_count).each do |process_number|
          context.execute "monit stop #{adapter}_#{app['shortname']}-#{process_number}" do
            retries 3
          end
        end
      end

      def process_count
        [out[:process_count].to_i, 1].max
      end

      def environment
        framework = Drivers::Framework::Factory.build(context, app, options)
        app['environment'].merge(framework.out[:deploy_environment] || {})
      end

      def check_status
        deploy_to = deploy_dir(app)

        (1..process_count).each do |process_number|
          name = "#{adapter}_#{app['shortname']}-#{process_number}"
          log_file = "#{deploy_to}/shared/log/#{name}.log"
          pid_file = "#{deploy_to}/shared/pids/#{name}.pid"

          context.ruby_block 'check_status' do
            block do
              begin
                command = "/bin/ps -q $(cat #{pid_file})"

                r = Chef::Resource::Execute.new(command, run_context)
                r.command command
                r.retries 3
                r.retry_delay 5
                r.returns 0
                r.run_action(:run)
              rescue StandardError => e
                Chef::Log.fatal("Could not start #{name} correctly.")
                Chef::Log.info("Printing #{log_file}…")
                Chef::Log.info(File.exist?(log_file) ? File.read(log_file) : '(does not exist)')
                raise e
              end
            end
          end
        end
      end
    end
  end
end
