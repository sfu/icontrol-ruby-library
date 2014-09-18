#!/usr/bin/ruby

require 'rubygems'
require 'f5-icontrol'

def usage
  puts $0 + ' <BIG-IP address> <BIG-IP user> <BIG-IP password>'
  exit
end

usage if $*.size < 3

# set up Management::Partition and LocalLB::Pool interfaces

bigip = F5::IControl.new($*[0], $*[1], $*[2], \
['Management.Partition', 'LocalLB.Pool']).get_interfaces

# grab a list of partition and loop through them

partitions = bigip['Management.Partition'].get_partition_list

partitions.each do |partition|

  # set the active partition to query

  partitions = bigip['Management.Partition'].set_active_partition(partition['partition_name'])

  puts ('#' * 5) + " #{partition['partition_name']} " + ('#' *5)
  puts

  # grab a list of pools and stuff the array into a variable

  pools = bigip['LocalLB.Pool'].get_list.sort

  pool_active_members = bigip['LocalLB.Pool'].get_active_member_count(pools)

  [ pools, pool_active_members ].transpose.each do |pool|
    puts "#{pool[0]} - #{pool[1]} available members"
  end

  puts
end
