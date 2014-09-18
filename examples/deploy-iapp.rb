#!/usr/bin/ruby

require 'rubygems'
require 'f5-icontrol'

host = 'test-bigip-01.example.com'

bigip = F5::IControl.new(host, 'admin', 'admin', ['Management.ApplicationService', 'Management.Device', 'System.Services']).get_interfaces

def is_bigip_ready? bigip, host
  services = [ 'SERVICE_MCPD', 'SERVICE_SCRIPTD' ]

  bigip['System.Services'].get_service_status(services).each do |service_status|
    return false if service_status['status'] != 'SERVICE_STATUS_UP'
  end
  
  return true if bigip['Management.Device'].get_failover_state([ host ])[0] != 'HA_STATE_ACTIVE'
  return false
end


until is_bigip_ready? bigip, host
  puts 'BIG-IP not active yet...'
  sleep 5
end

apps = [ 'http_test' ]
templates = [ 'f5.http' ]
scalar_vars = [ [ { 'name' => 'analytics__add_analytics', 'value' => 'No' },
                  { 'name' => 'optimizations__use_wa', 'value' => 'No' },
                  { 'name' => 'optimizations__lan_or_wan', 'value' => 'No' },
                  { 'name' => 'ssl_encryption_questions__offload_ssl', 'value' => 'No' },
                  { 'name' => 'basic__addr', 'value' => '10.0.0.1' },
                  { 'name' => 'basic__port', 'value' => 80 },
                  { 'name' => 'basic__snat', 'value' => 'Yes' },
                  { 'name' => 'basic__need_snatpool', 'value' => 'No' },
                  { 'name' => 'basic__using_ntlm', 'value' => 'No' },
                  { 'name' => 'server_pools__create_new_pool', 'value' => 'Create New Pool' },
                  { 'name' => 'server_pools__create_new_monitor', 'value' => 'Create New Monitor' },
                  { 'name' => 'server_pools__monitor_interval', 'value' => 16 },
                  { 'name' => 'server_pools__monitor_send', 'value' => 'GET /' },
                  { 'name' => 'server_pools__monitor_recv', 'value' => '' },
                  { 'name' => 'server_pools__monitor_http_version', 'value' => 'Version 1.0' },
                  { 'name' => 'server_pools__lb_method_choice', 'value' => 'round-robin' },
                  { 'name' => 'server_pools__tcp_request_queuing_enable_question', 'value' => 'No' }
                ] ]

table_vars =  [ [ { 'name' => 'server_pools__servers',
                  'column_names' => [ 'addr', 'port', 'connection_limit'],
                  'values' => [ [ '10.10.0.1', 80, 0 ],
                                [ '10.10.0.2', 80, 0 ],
                                [ '10.10.0.3', 80, 0 ] ] 
              } ] ]

list_vars = [ { } ]

bigip['Management.ApplicationService'].create(apps, templates, scalar_vars, list_vars, table_vars)
