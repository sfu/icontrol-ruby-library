#!/usr/bin/ruby

require 'rubygems'
require 'f5-icontrol'

def usage 
  puts $0 + ' <BIG-IP address> <BIG-IP user> <BIG-IP password> <WideIP> <WideIP pool>'
  exit
end

usage if $*.size < 4

bigip = F5::IControl.new($*[0], $*[1], $*[2], ['GlobalLB.WideIP']).get_interfaces

wips = bigip['GlobalLB.WideIP'].get_list

unless wips.include? $*[3]
  puts "Error: the specified WideIP is not available on this BIG-IP"
  exit 1
end

wip_pools = bigip['GlobalLB.WideIP'].get_wideip_pool([ $*[3] ]).slice(0).collect do |pool| 
  { 'pool_name' => pool.pool_name, \
    'ratio' => pool.ratio, \
    'order' => pool.order }
end

unless wip_pools.collect { |pool| pool['pool_name'] }.include? $*[4]
  puts "Error: the specified WideIP pool is not available for the specified WideIP on this BIG-IP"
  exit 1
end

wip_pool_def = wip_pools.select { |pool| pool['pool_name'] == $*[4] }.slice(0)

begin
  bigip['GlobalLB.WideIP'].remove_wideip_pool([ $*[3] ], [ [ wip_pool_def ] ])
  puts "Info: WideIP pool '" + $*[4] + "' has been removed from WideIP '" + $*[3] + "'"
rescue
  puts "Error: could not remove the specified WideIP pool from the WideIP"
  exit 1
end
