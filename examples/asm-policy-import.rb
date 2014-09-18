#!/usr/bin/ruby

require 'rubygems'
require 'f5-icontrol'

def usage 
  puts $0 + ' <BIG-IP address> <BIG-IP user> <BIG-IP password> <Virtual Server name> <ASM policy file>'
  exit
end

usage if $*.size < 5

# setup connection to BIG-IP iControl service
interfaces = ['ASM.Policy', 'ASM.WebApplication', 'LocalLB.ProfileHttpClass', 'LocalLB.VirtualServer']
bigip = F5::IControl.new($*[0], $*[1], $*[2], interfaces).get_interfaces
puts 'Connected to BIG-IP at "' + $*[0] + '" with username "' + $*[1] + '"...'

def download_policy bigip, policy_file, dest_file
  file = File.open dest_file, 'w'
  chunk_size = 64 * 1024
  offset = 0

  puts "Downloading ASM policy file '#{policy_file}'..." 

  while
    file_transfer_context = bigip['ASM.Policy'].download_policy(policy_file, chunk_size, offset)[0]
    file.write file_transfer_context.file_data
    break if ['FILE_LAST', 'FILE_FIRST_AND_LAST'].include? file_transfer_context.chain_type
    offset += chunk_size
  end 

  file.close
end

def upload_policy bigip, policy_file, source_file
  file = File.open source_file, 'r'
  file_size = File.size source_file
  chunk_size = 64 * 1024.0
  chunk_count = (file_size/chunk_size).ceil

  puts "Uploading ASM policy file '#{policy_file}'..."

  for chunk in 1..chunk_count
    if chunk_count == 1 
      chain_type = 'FILE_FIRST_AND_LAST'
    elsif chunk == 1
      chain_type = 'FILE_FIRST'
    elsif chunk == chunk_count
      chain_type = 'FILE_LAST'
    else 
      chain_type = 'FILE_MIDDLE'
    end

    file_data = file.read chunk_size
    file_transfer_context = { 'file_data' => file_data, 'chain_type' => chain_type }
    bigip['ASM.Policy'].upload_policy policy_file, file_transfer_context
  end

  file.close
end

def create_webapp bigip, webapp_name, language
  puts "Creating HTTP class '#{webapp_name}'..."
  unless bigip['LocalLB.ProfileHttpClass'].get_list.include? webapp_name
    bigip['LocalLB.ProfileHttpClass'].create [webapp_name]
  end

  puts "Enabling ASM module on HTTP class '#{webapp_name}'..."
  if bigip['LocalLB.ProfileHttpClass'].get_application_security_module_enabled_state(webapp_name)[0].value == "STATE_DISABLED"
    bigip['LocalLB.ProfileHttpClass'].set_application_security_module_enabled_state \
      [webapp_name], [{ 'value' => 'STATE_ENABLED', 'default_flag' => 'false' }] 
  end 

  # operations happen asynchronously on the BIG-IP, sleep necessary to avoid race condition
  sleep 1
  puts "Setting language for ASM web app '#{webapp_name}' to #{language}..."
  bigip['ASM.WebApplication'].set_language [webapp_name], language
end

def import_policy bigip, policy_file
  policies = bigip['ASM.Policy'].get_list
  puts "Importing ASM policy file '#{policy_file}'..."
  bigip['ASM.Policy'].import_policy '', "/var/tmp/#{policy_file}"
  policy_name = (bigip['ASM.Policy'].get_list - policies)[0]
  puts "Imported ASM policy '#{policy_name}'..."
  return policy_name
end

def bind_policy bigip, vs_name, webapp_name, policy_name
  puts "Binding ASM policy '#{File.basename policy_name}' to web app '#{webapp_name}'..."
  bigip['ASM.WebApplication'].set_active_policy webapp_name, policy_name
  puts "Assigning ASM-enabled HTTP class '#{File.basename policy_name}' to virtual server '#{vs_name}'..."
  profile = [[{ 'profile_name' => webapp_name, 'priority' => 1 }]]
  bigip['LocalLB.VirtualServer'].add_httpclass_profile [vs_name], profile
end

def cleanup_default_policy bigip, webapp_name
  webapp_name = File.basename webapp_name
  if bigip['ASM.Policy'].get_list.include? webapp_name
    bigip['ASM.Policy'].delete_policy [webapp_name]
  end
end

# main
timestamp = Time.now.strftime '%Y-%m-%d-%H%M%S'
vs_name = $*[3]
policy_file = $*[4]

# upload local ASM binary policy to BIG-IP
upload_policy bigip, File.basename(policy_file), policy_file

# import the policy file and return the name of the policy 
policy_name = import_policy bigip, File.basename(policy_file)

# create an HTTP class/web app to assign the ASM policy
webapp_name = "/Common/#{policy_name}_#{timestamp}"
create_webapp bigip, webapp_name, 'UNICODE_UTF_8'

# bind the policy to the HTTP class/web app and virtual server
bind_policy bigip, vs_name, webapp_name, policy_name

# remove default policy that gets auto created when ASM is enabled on the HTTP class
cleanup_default_policy bigip, webapp_name
