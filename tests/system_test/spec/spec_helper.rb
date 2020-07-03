require 'serverspec'
require 'net/ssh'

set :backend, :ssh

if ENV['ASK_SUDO_PASSWORD']
  begin
    require 'highline/import'
  rescue LoadError
    fail "highline is not available. Try installing it."
  end
  set :sudo_password, ask("Enter sudo password: ") { |q| q.echo = false }
else
  set :sudo_password, ENV['SUDO_PASSWORD']
end

host = ENV['TARGET_HOST']

options = Net::SSH::Config.for(host)

options[:user] ||= Etc.getlogin

set :host,        options[:host_name] || host
set :ssh_options, options

def network_composition_of_master
  internet_mode = 'eth'
  mesh_mode = 'aponly'
  network_composition = mesh_mode + '_' + internet_mode
  
  if File.exist?("/etc/rdbox/wpa_supplicant_yoursite.conf")
    internet_mode = 'wlan'
  else
    internet_mode = 'eth'
  end
  
  _wlan_count = `ls /sys/class/net | grep -E "^wlan[0-9]" | wc -l`
  if _wlan_count.to_i == 1
    mesh_mode = 'aponly'
  elsif _wlan_count.to_i == 2
    mesh_mode = 'mesh'
  else
    mesh_mode = 'aponly'
  end
  
  network_composition = mesh_mode + '_' + internet_mode
  return network_composition
end


# Disable sudo
# set :disable_sudo, true


# Set environment variables
# set :env, :LANG => 'C', :LC_MESSAGES => 'C'

# Set PATH
# set :path, '/sbin:/usr/local/sbin:$PATH'
