#!/bin/bash

set +x
set -e

cd /opt/devstack || { echo "cannot cd into devstack dir"; exit 1; }
source openrc admin admin

IMG_ID=$(nova image-list | grep 'cirros-0.3..-x86_64-uec\s' | tail -1 | awk '{print $2}')
TNT_ID=$(keystone tenant-list 2> /dev/null | grep '\s'tenant2'' | awk '{print $2}')

# Set into tenant2's context
unset SERVICE_TOKEN SERVICE_ENDPOINT
export OS_USERNAME=user2
export OS_TENANT_NAME=tenant2
export OS_PASSWORD=user2
export PS1='[\u@\h \W(keystone_user2)]\$ '

set -x

# Create an ssh key, if there is not one yet
if [[ ! -f id_rsa_demo || ! -f id_rsa_demo.pub ]]; then
    rm -f id_rsa_demo id_rsa_demo.pub
    ssh-keygen -t rsa -b 2048 -N '' -f id_rsa_demo
fi

nova keypair-add --pub-key id_rsa_demo.pub demo_key > /dev/null
neutron router-create rtr
neutron router-gateway-set rtr ext2

neutron net-create net1
neutron subnet-create net1 10.2.0.0/24 --name subnet1 --dns-nameserver 192.168.111.254
neutron router-interface-add rtr subnet1

neutron router-list

NET1_ID=$(neutron net-list | grep -w net1 | awk '{print $2}') ; echo "net1 $NET1_ID"

for VMNAME in vm1 vm2 ; do
    nova boot --poll --flavor m1.nano --image $IMG_ID --key-name demo_key --nic net-id=${NET1_ID} ${VMNAME}
    sleep 20

    neutron floatingip-create ext2
    FLOAT_IP=$(neutron floatingip-list | grep 192\.168\.111\. | grep -v 10\..\.0\. | head -1 | awk '{print $5}')
    echo "Assigning floating ip ${FLOAT_IP} to ${VMNAME}"
    nova floating-ip-associate ${VMNAME} ${FLOAT_IP}
done

nova list
