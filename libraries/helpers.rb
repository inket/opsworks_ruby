# frozen_string_literal: true

def applications
  if Chef::Config[:solo]
    Chef::Log.warn('This recipe uses search. Chef Solo does not support search.')
  end
  search(:aws_opsworks_app)
end

def rdses
  if Chef::Config[:solo]
    Chef::Log.warn('This recipe uses search. Chef Solo does not support search.')
  end
  search(:aws_opsworks_rds_db_instance)
end

def layers
  aws_instance = search(:aws_opsworks_instance, "hostname:#{node["hostname"].upcase}").first
  aws_instance["layer_ids"].map do |layer_id|
    layer = search(:aws_opsworks_layer, "layer_id:#{layer_id}").first
    layer ? layer["shortname"] : nil
  end.compact
end

def globals(index, application)
  globals = (node['deploy'][application].try(:[], 'global') || {}).symbolize_keys
  return globals[index.to_sym] unless globals[index.to_sym].nil?

  old_item = old_globals(index, application)
  return old_item unless old_item.nil?
  node['defaults']['global'][index.to_s]
end

def old_globals(index, application)
  return unless node['deploy'][application][index.to_s]
  message =
    "DEPRECATION WARNING: node['deploy']['#{application}']['#{index}'] is deprecated and will be removed. " \
    "Please use node['deploy']['#{application}']['global']['#{index}'] instead."
  Chef::Log.warn(message)
  STDERR.puts(message)
  node['deploy'][application][index.to_s]
end

def fire_hook(name, options)
  Array.wrap(options[:items]).each do |item|
    old_context = item.context
    item.context = options[:context] if options[:context].present?
    item.send(name)
    item.context = old_context
  end
end

def www_group
  value_for_platform_family(
    'debian' => 'www-data'
  )
end

def create_deploy_dir(application, subdir = '/')
  dir = File.join(deploy_dir(application), subdir)
  directory dir do
    mode '0755'
    recursive true
    owner node['deployer']['user'] || 'root'
    group www_group
    not_if { File.directory?(dir) }
  end
  dir
end

def deploy_dir(application)
  File.join('/', 'srv', 'www', application['shortname'])
end

def every_enabled_application
  node['deploy'].keys.each do |deploy_app_shortname|
    application = applications.detect { |app| app['shortname'] == deploy_app_shortname }
    next unless application && application['deploy']
    yield application
  end
end

def every_enabled_rds(context, application)
  data = rdses.presence || [Drivers::Db::Factory.build(context, application)]
  data.each do |rds|
    yield rds
  end
end

def perform_ruby_build
  ruby_version = File.read(File.join(release_path, '.ruby-version')).strip

  Chef::Log.info("Currently installed ruby version: #{`ruby -v`}") rescue nil
  Chef::Log.info("Installing detected ruby version: #{ruby_version} (from .ruby-version)")

  include_recipe 'ruby_build::default'
  ruby_build_ruby ruby_version do
    prefix_path '/usr/local'
  end

  Chef::Log.info("Installed ruby version: #{`ruby -v`}")

  gem_package 'bundler' do
    action :install
  end

  link '/usr/local/bin/bundle' do
    to '/usr/local/bin/bundler'
  end
end

def perform_bundle_install(shared_path, envs = {})
  bundle_path = "#{shared_path}/vendor/bundle"

  execute 'bundle_install' do
    command "/usr/local/bin/bundle install --deployment --without development test --path #{bundle_path}"
    user node['deployer']['user'] || 'root'
    group www_group
    environment envs
    cwd release_path
  end
end

def perform_node_install
  Chef::Log.info("Currently installed node version: #{`node -v`}") rescue nil

  nvmrc_path = File.join(release_path, '.nvmrc')

  unless File.exist?(nvmrc_path)
    Chef::Log.warn("No .nvmrc file found in project. Skipping nodejs install.")
    return
  end

  node_version = File.read(nvmrc_path).strip
  node.default['nodejs']['version'] = node_version

  Chef::Log.info("Installing detected nodejs version: #{node_version} (from .nvmrc)")
  include_recipe 'nodejs::nodejs_from_binary'
  Chef::Log.info("Installed node version: #{`node -v`}")
end

def perform_yarn_install
  Chef::Log.info("Currently installed yarn version: #{`yarn --version`}") rescue nil

  package_json_path = File.join(release_path, 'package.json')

  unless File.exist?(package_json_path)
    Chef::Log.warn('No package.json file found in project. Skipping yarn install.')
    return
  end

  unless (`node -v` rescue nil)
    Chef::Log.warn('No nodejs installed. Skipping yarn install.')
    return
  end

  Chef::Log.info('Installing the latest version of yarn…')
  include_recipe 'yarn::upgrade_package'
  Chef::Log.info("Installed yarn version: #{`yarn --version`}")

  Chef::Log.info('Linking node_modules to shared node_modules…')
  shared_node_modules_path = File.join(release_path, '..', '..', 'shared', 'node_modules')
  directory shared_node_modules_path do
    owner node['deployer']['user'] || 'root'
    group node['deployer']['group'] || 'root'
    mode '0755'
    recursive true
    action :create
  end

  node_modules_path = File.join(release_path, 'node_modules')
  link node_modules_path do
    to shared_node_modules_path
  end

  Chef::Log.info('Running yarn install…')
  yarn_install_production release_path do
    user node['deployer']['user'] || 'root'
    action :run
  end
end

def prepare_recipe
  node.default['deploy'] = Hash[applications.map { |app| [app['shortname'], {}] }].merge(node['deploy'] || {})
  apps_not_included.each do |app_for_removal|
    node.rm('deploy', app_for_removal)
  end
end

def apps_not_included
  return [] if node['applications'].blank?
  node['deploy'].keys.reject { |app_name| node['applications'].include?(app_name) }
end
