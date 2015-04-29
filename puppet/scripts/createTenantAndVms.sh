#!/usr/bin/env bash
#

export TNT_ID=${TNT_ID:-1}
export VM_COUNT=${VM_COUNT:-2}

cd /home/vagrant/devstack

source openrc admin admin

keystone tenant-create --name=tenant${TNT_ID} --enabled=true
keystone user-create --name=user${TNT_ID} --pass=user${TNT_ID} --email=user${TNT_ID}@example.com
keystone user-role-add --user=user${TNT_ID} --role=Member --tenant=tenant${TNT_ID}

source openrc user${TNT_ID} tenant${TNT_ID} ; export OS_PASSWORD=user${TNT_ID}

if [ ! -f id_rsa_demo.pub ]; then ssh-keygen -t rsa -b 2048 -N '' -f id_rsa_demo; fi
nova keypair-add --pub-key  id_rsa_demo.pub  demo_key

nova secgroup-create sec1 sec1
nova secgroup-add-rule sec1 icmp -1 -1 0.0.0.0/0
for x in tcp udp; do nova secgroup-add-rule sec1 ${x} 1 65535 0.0.0.0/0 ; done

neutron net-create int
neutron subnet-create --gateway=2.0.0.254 --name=subint int 2.0.0.0/24 --enable-dhcp

IMAGE=$(nova image-list | grep 'cirros.*uec\s' | awk '{print $2}')
NETID=$(neutron net-list | grep -w int | awk '{print $2}')
    
for x in `seq 1 ${VM_COUNT}` ; do \
    VMNAME="vm${x}"
    echo creating ${TNT_ID}_${VMNAME}
    nova boot --poll --flavor m1.nano --image ${IMAGE} --nic net-id=${NETID} \
    --security-groups sec1 --key-name demo_key \
    ${TNT_ID}_${VMNAME}
    sleep 5
done

# 
# source openrc user1 tenant1 ; export OS_PASSWORD=user1
# source openrc user2 tenant2 ; export OS_PASSWORD=user2
# source openrc user${TNT_ID} tenant${TNT_ID} ; export OS_PASSWORD=user${TNT_ID}
# source openrc admin admin
#

