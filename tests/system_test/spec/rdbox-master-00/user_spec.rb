require 'serverspec'
set :backend, :exec

describe user('ubuntu') do
  it { should exist }
  it { should belong_to_group 'docker'}
end

describe file('/home/ubuntu/.ssh/') do
  it { should be_directory }
  it { should exist }
  it { should be_mode 700 }
end

describe x509_private_key('/home/ubuntu/.ssh/id_rsa') do
  it { should_not be_encrypted }
  it { should be_valid }
end

describe file('/home/ubuntu/.ssh/id_rsa') do
  it { should be_file }
  it { should exist }
  its(:content) { should match /^-----BEGIN RSA PRIVATE KEY-----/ }
  it { should be_mode 600 }
end

describe file('/home/ubuntu/.ssh/authorized_keys') do
  it { should be_file }
  it { should exist }
  its(:content) { should match /^ssh-rsa/ }
  it { should be_mode 600 }
end