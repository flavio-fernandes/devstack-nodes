#!/bin/bash

set +x
set -e
cd /opt/devstack || { echo "cannot cd into devstack dir"; exit 1; }
source openrc admin admin
set -x

keystone tenant-create --name=tenant1 --enabled=true                     2> /dev/null
keystone user-create --name=user1 --pass=user1 --email=user1@example.com 2> /dev/null
keystone user-role-add --user=user1 --role=_member_ --tenant=tenant1     2> /dev/null
 
keystone tenant-create --name=tenant2 --enabled=true                     2> /dev/null
keystone user-create --name=user2 --pass=user2 --email=user2@example.com 2> /dev/null
keystone user-role-add --user=user2 --role=_member_ --tenant=tenant2     2> /dev/null

IMG_ID=$(nova image-list | grep 'cirros-0.3..-x86_64-uec\s' | tail -1 | awk '{print $2}')
TNT1_ID=$(keystone tenant-list 2> /dev/null | grep '\s'tenant1'' | awk '{print $2}')
TNT2_ID=$(keystone tenant-list 2> /dev/null | grep '\s'tenant2'' | awk '{print $2}')

# create external net for tenant1
neutron net-create ext1 --router:external --tenant_id=${TNT1_ID} --provider:network_type flat \
   --provider:physical_network physnetext1

neutron subnet-create --tenant_id=${TNT1_ID} \
   --allocation-pool start=192.168.111.21,end=192.168.111.40 --gateway=192.168.111.254 \
   --disable-dhcp --name subext1 ext1 192.168.111.0/24

# create external net for tenant2
neutron net-create ext2 --router:external --tenant_id=${TNT2_ID} --provider:network_type flat \
   --provider:physical_network physnetext2

neutron subnet-create --tenant_id=${TNT2_ID} \
   --allocation-pool start=192.168.111.41,end=192.168.111.60 --gateway=192.168.111.254 \
   --disable-dhcp --name subext2 ext2 192.168.111.0/24

