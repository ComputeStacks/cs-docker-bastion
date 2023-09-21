require 'rubygems'
require "http"
require 'oj'
require 'timeout'

begin
  project_ssh_keys = Timeout::timeout(5) do
    Oj.load HTTP.auth("Bearer #{ENV['METADATA_AUTH']}").get("#{ENV['METADATA_SERVICE']}/ssh_keys?raw=true").body
  end

  unless project_ssh_keys
    puts "Timeout reached during metadata ssh lookup, exiting."
    exit 0 # Exit 1 will break the remainder of the bootup sequence
  end

  user_keys = project_ssh_keys['ssh_keys'].join("\n")

  puts "Installing SSH Public Keys..."
  `mkdir -p /home/sftpuser/.ssh && chmod 700 /home/sftpuser/.ssh && chown sftpuser:users /home/sftpuser/.ssh`
  if project_ssh_keys['ssh_keys'].empty?
    puts "...No SSH Public keys found."
    `if [ -f /home/sftpuser/.ssh/authorized_keys ]; then rm /home/sftpuser/.ssh/authorized_keys; fi`
  else
    puts "...writing ssh keys."
    File.open('/home/sftpuser/.ssh/authorized_keys', 'w') do |f|
      f.write user_keys
    end
    `chown sftpuser:users /home/sftpuser/.ssh/authorized_keys && chmod 600 /home/sftpuser/.ssh/authorized_keys`
  end

rescue => e
  puts "Fatal error: #{e.message}"
end
