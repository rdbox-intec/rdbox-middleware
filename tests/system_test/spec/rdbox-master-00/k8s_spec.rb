require 'serverspec'
require 'spec_helper'

describe package('kubeadm') do
  it { should be_installed }
end

describe interface('flannel.1') do
  it { should exist }
end