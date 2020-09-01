require 'serverspec'
require 'spec_helper'

set :backend, :exec

describe package('rdbox') do
  it { should be_installed }
end

describe service('rdbox-boot') do
  it { should be_enabled }
  it { should be_running }
end

describe file('/var/lib/rdbox/.completed_first_session') do
  it { should be_file }
  it { should exist }
  its(:content) { should match /simplexmst/ }
end

describe file('/var/lib/rdbox/.is_simple') do
  it { should be_file }
  it { should exist }
  its(:content) { should match /true/ }
end

network_composition = network_composition_of_master

if network_composition == 'mesh_wlan'
  describe bridge('br0') do
    it { should exist }
    let(:stdout) { 'awlan1' }
    it { should have_interface 'awlan1' }
    let(:stdout) { 'bat0' }
    it { should have_interface 'bat0' }
    let(:stdout) { 'eth0' }
    it { should have_interface 'eth0' }
  end

  describe interface('br0') do
    ip_vpnrdbox=`ip -f inet -o addr show vpn_rdbox|cut -d\' ' -f 7 | cut -d/ -f 1 | tr -d '\n'`
    ip_vpnrdbox_fourth=ip_vpnrdbox.split('.')[3]
    ip_br0='192.168.' + ip_vpnrdbox_fourth + '.1/24'
    it { should exist }
    its(:ipv4_address) { should eq ip_br0 }
  end

  describe interface('eth0') do
    it { should exist }
    its(:ipv4_address) { should eq '' }
  end

  describe interface('wlan0') do
    it { should exist }
    it { should be_up }
    its(:ipv4_address) { should match /\d\.\d\.\d.\d/ }
  end

  describe interface('wlan1') do
    it { should exist }
    its(:ipv4_address) { should eq '' }
  end

  describe interface('vpn_rdbox') do
    it { should exist }
    its(:ipv4_address) { should match /192\.168\./ }
  end

  describe interface('bat0') do
    it { should exist }
    its(:ipv4_address) { should eq '' }
  end

  describe interface('awlan0') do
    it { should exist }
    it { should be_up }
    its(:ipv4_address) { should eq '' }
  end

  describe interface('awlan1') do
    it { should exist }
    it { should be_up }
    its(:ipv4_address) { should eq '' }
  end

  describe default_gateway do
    its(:interface) { should eq 'wlan0' }
  end

  describe process("wpa_supplicant") do
    it { should be_running }
    its(:count) { should eq 1 }
    its(:args) { should eq "/sbin/wpa_supplicant -B -f /var/log/rdbox/rdbox_boot_wpa.log -P /run/wpa_supplicant.pid -D nl80211 -i wlan0 -c /etc/rdbox/wpa_supplicant_yoursite.conf" }
  end

end

describe kernel_module('batman_adv') do
  it { should be_loaded }
end

describe 'Linux kernel parameters' do
  context linux_kernel_parameter('net.ipv4.conf.all.forwarding') do 
    its(:value) { should eq 1 }
  end
  context linux_kernel_parameter('net.ipv4.conf.default.forwarding') do 
    its(:value) { should eq 1 }
  end
  context linux_kernel_parameter('net.ipv4.ip_forward') do 
    its(:value) { should eq 1 }
  end
  context linux_kernel_parameter('net.ipv6.conf.all.forwarding') do 
    its(:value) { should eq 1 }
  end
  context linux_kernel_parameter('net.ipv6.conf.default.forwarding') do 
    its(:value) { should eq 1 }
  end
  context linux_kernel_parameter('net.ipv6.conf.all.disable_ipv6') do 
    its(:value) { should eq 1 }
  end
  context linux_kernel_parameter('net.ipv6.conf.default.disable_ipv6') do 
    its(:value) { should eq 1 }
  end
end

describe command('cat `find /sys/devices/ -name wlan0 2>/dev/null`/address') do
  its(:stdout) { should match /^dc:a6:32:|^b8:27:eb:/ }
end

describe package('curl') do
  it { should be_installed }
end

test_host = 'www.intec.co.jp'
describe host(test_host) do
  it { should be_resolvable.by('dns') }
end

describe command('curl https://www.intec.co.jp/ -o /dev/null -w "%{http_code}\n" -s') do
  its(:stdout) { should match /^200$/ }
end

%w{softether-vpnclient softether-vpncmd}.each do |pkg|
  describe package(pkg) do
    it { should be_installed }
  end
end

describe service('softether-vpnclient') do
  it { should be_enabled }
  it { should be_running }
end

describe package('dnsmasq') do
  it { should be_installed }
end

describe service('dnsmasq') do
  it { should be_enabled }
  it { should be_running }
end

describe port(5353) do
  it { should be_listening }
end

describe file('/etc/dnsmasq.conf') do
  location = host_inventory['hostname'].split('-')[2]
  domain = 'domain=' + location + '.' + host_inventory['fqdn']
  local = 'local=/' + location + '.' + host_inventory['fqdn'] + '/'
  its(:content) { should match domain }
  its(:content) { should match local }
  its(:content) { should match /port=5353/ }
end

describe package('bind9') do
  it { should be_installed }
end

describe service('bind9') do
  it { should be_enabled }
  it { should be_running }
end

describe port(53) do
  it { should be_listening }
end

k8s_master_host = 'rdbox-k8s-master'
describe host(k8s_master_host) do
  it { should be_resolvable.by('dns') }
end

k8s_master_host = 'rdbox-k8s-master.hq.rdbox.lan'
describe host(k8s_master_host) do
  it { should be_resolvable.by('dns') }
end

describe command('sudo ping -w 5 -c 2 -n rdbox-k8s-master') do
  its(:exit_status) { should eq 0 }
end

k8s_vpnserver_host = 'rdbox-vpnserver-01'
describe host(k8s_vpnserver_host) do
  it { should be_resolvable.by('dns') }
end

k8s_vpnserver_host = 'rdbox-vpnserver-01.hq.rdbox.lan'
describe host(k8s_vpnserver_host) do
  it { should be_resolvable.by('dns') }
end

describe command('sudo ping -w 5 -c 2 -n rdbox-vpnserver-01') do
  its(:exit_status) { should eq 0 }
end

describe package('wpasupplicant') do
  it { should be_installed }
end

describe package('hostapd') do
  it { should be_installed }
end

describe process("hostapd") do
  it { should be_running }
  its(:count) { should eq 1 }
  its(:args) { should eq "/usr/sbin/hostapd -B -f /var/log/rdbox/rdbox_boot_hostapd.log -P /run/hostapd.pid /etc/rdbox/hostapd_ap_bg.conf /etc/rdbox/hostapd_be.conf" }
end

describe service('ntp') do
  it { should be_enabled }
  it { should be_running }
end