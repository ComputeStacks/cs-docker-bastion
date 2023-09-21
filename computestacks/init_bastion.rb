require 'rubygems'
require "http"
require 'oj'
require 'timeout'

begin
  bastion_metadata = Timeout::timeout(5) do
    Oj.load HTTP.auth("Bearer #{ENV['METADATA_AUTH']}").get("#{ENV['METADATA_SERVICE']}/#{ENV['HOSTNAME']}?raw=true").body
  end

  unless bastion_metadata
    puts "Timeout reached during metadata lookup, exiting."
    exit 0
  end

  host_keys = bastion_metadata['host_keys']
  motd = bastion_metadata['motd'].strip.length.zero? ? nil : bastion_metadata['motd']
  pw_auth = bastion_metadata['password_auth']

  puts "Setting Password Authentication"
  if pw_auth
    `sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config`
  else
    `sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config`
  end

  puts "Install SSH Host Keys"
  puts "...rsa..."
  if File.exist?("/etc/ssh/ssh_host_rsa_key")
    puts "...exists, skipping."
  else
    puts "...writing ssh_host_rsa_key."
    File.open("/etc/ssh/ssh_host_rsa_key", "w") do |f|
      f.write host_keys['rsa']['pkey']
    end
    puts "...writing ssh_host_rsa_key.pub."
    File.open("/etc/ssh/ssh_host_rsa_key.pub", "w") do |f|
      f.write host_keys['rsa']['pubkey']
    end
    `chmod 400 /etc/ssh/ssh_host_rsa_key`
  end
  puts "...ed25519..."
  if File.exist?("/etc/ssh/ssh_host_ed25519_key")
    puts "...exists, skipping."
  else
    puts "...writing ssh_host_ed25519_key."
    File.open("/etc/ssh/ssh_host_ed25519_key", "w") do |f|
      f.write host_keys['ed25519']['pkey']
    end
    puts "...writing ssh_host_ed25519_key.pub."
    File.open("/etc/ssh/ssh_host_ed25519_key.pub", "w") do |f|
      f.write host_keys['ed25519']['pubkey']
    end
    `chmod 400 /etc/ssh/ssh_host_ed25519_key`
  end

  if motd
    puts "Configuring motd..."
    File.open('/etc/motd', 'w') do |f|
      f.write motd
    end
  end
rescue => e
  puts "Fatal error: #{e.message}"
end