#!/usr/bin/env bash
#

# This shell script will perform steps neutron and ovs would take in order to
# create a net, router, tenant vm and associate floating ip. With that, it
# will interact with a running Opendaylight as if it was a real Openstack
# environment.

# Ref: https://lists.opendaylight.org/pipermail/ovsdb-dev/2015-June/001544.html

# To use this script:
#
# 1) start ODL
#
# 2) copy this script to a system that has OVS installed and running.
#    Make sure ODL_IP is correct
#
# 3) set manager of ovs to ODL (see setup_ovs function in this script)
#
# 4) verify that OVS connected to ODL okay, as well as pipeline in OVS is created
#    An example for doing such is here: https://gist.github.com/391c9ba88d2c58cf40f7
#
# 5) run this script. Tweak away!

export ODL_IP='192.168.50.1'
export ODL_PORT='8080'
export ODL="http://${ODL_IP}:${ODL_PORT}/controller/nb/v2/neutron"
export DEBUG=1
# export DEBUG_FAKE_POST=yes
# export DEBUG_FAKE_OVS=yes

export CURL_HEADERS=('-H "Authorization: Basic YWRtaW46YWRtaW4="' '-H "Accept: application/json"' '-H "Content-Type: application/json"' '-H "Cache-Control: no-cache"')
export CURL_POST="curl -X POST ${CURL_HEADERS[*]}"
export CURL_PUT="curl -X PUT ${CURL_HEADERS[*]}"
export CURL_RETURN_FORMAT='-o /dev/null -sL -w "%{http_code}"'

export BIND_HOST_ID=$(hostname)
export TNT1_ID='cde2563ead464ffa97963c59e002c0cf'
export EXT_NET1_ID='7da709ff-397f-4778-a0e8-994811272fdb'
export EXT_SUBNET1_ID='00289199-e288-464a-ab2f-837ca67101a7'
export TNT1_RTR_ID='e09818e7-a05a-4963-9927-fc1dc6f1e844'
export NEUTRON_PORT_TNT1_RTR_GW='8ddd29db-f417-4917-979f-b01d4b1c3e0d'
export NEUTRON_PORT_TNT1_RTR_NET1='9cc1af22-108f-40bb-b938-f1da292236bf'

export TNT1_NET1_NAME='net1'
export TNT1_NET1_SEGM='1062'
export TNT1_NET1_ID='12809f83-ccdf-422c-a20a-4ddae0712655'
export TNT1_SUBNET1_NAME='subnet1'
export TNT1_SUBNET1_ID='6c496958-a787-4d8c-9465-f4c4176652e8'

export TNT1_NET1_DHCP_PORT_ID='79adcba5-19e0-489c-9505-cc70f9eba2a1'
export TNT1_NET1_DHCP_MAC='FA:16:3E:8F:70:A9'
export TNT1_NET1_DHCP_DEVICE_ID="dhcp58155ae3-f2e7-51ca-9978-71c513ab02ee-${TNT1_NET1_ID}"
export TNT1_NET1_DHCP_OVS_PORT='tap79adcba5-19'

export TNT1_VM1_PORT_ID='341ceaca-24bf-4017-9b08-c3180e86fd24'
export TNT1_VM1_MAC='FA:16:3E:8E:B8:05'
export TNT1_VM1_DEVICE_ID='20e500c3-41e1-4be0-b854-55c710a1cfb2'
export TNT1_NET1_VM1_OVS_PORT='tap341ceaca-24'
export TNT1_VM1_VM_ID='20e500c3-41e1-4be0-b854-55c710a1cfb2'

export FLOAT_IP1_ID='f013bef4-9468-494d-9417-c9d9e4abb97c'
export FLOAT_IP1_PORT_ID='01671703-695e-4497-8a11-b5da989d2dc3'
export FLOAT_IP1_MAC='FA:16:3E:3F:37:BB'
export FLOAT_IP1_DEVICE_ID='f013bef4-9468-494d-9417-c9d9e4abb97c'
export FLOAT_IP1_ADDRESS='192.168.111.22'

#--

function do_eval_command {
    callerFunction=$1 ; shift
    expectedRc=$1     ; shift
    cmd="$*"          ; shift

    [ $DEBUG -gt 0 ] && echo -n "$callerFunction $cmd ==> "
    [ -z $DEBUG_FAKE_POST ] && rc=$(eval $cmd) || rc=fake
    [ $DEBUG -gt 0 ] && echo "$rc" && echo

    [ -z "$expectedRc" ] && expectedRc=201
    if [ "$rc" != "$expectedRc" ] && [ -z $DEBUG_FAKE_POST ]; then
	echo "ERROR: $callerFunction $cmd unexpected rc $rc (wanted $expectedRc)"
	exit 1
    fi
}

#--

function check_get_code {
    url="${ODL}/$1" ; shift
    cmd="curl -X GET ${CURL_HEADERS[*]} $CURL_RETURN_FORMAT $url 2>&1"

    [ -z "$1" ] && expectedRc=200 || expectedRc=$1
    do_eval_command ${FUNCNAME[0]} $expectedRc $cmd
}

#--

function setup_ovs {
    if [ -z $DEBUG_FAKE_OVS ]; then
	[ $DEBUG -gt 0 ] && echo "setting ovs manager to tcp:${ODL_IP}:6640"
	sudo ovs-vsctl set-manager tcp:${ODL_IP}:6640 || exit 2
	# give it time for pipeline to be created...
	sleep 10
    fi
}

#--

function create_ovs_port {
    callerFunction=$1  ; shift
    expectedSuccess=$1 ; shift
    ovsPort=$1         ; shift
    macAddrRaw=$1      ; shift
    neutronPortId=$1   ; shift
    portVmId=$1        ; shift

    macAddr="$(echo $macAddrRaw | tr '[:upper:]' '[:lower:]')"

    cmd1=$(cat <<EOF
sudo ovs-vsctl add-port br-int ${ovsPort}
     -- set Interface ${ovsPort} type=internal
     -- set Interface ${ovsPort} external_ids:attached-mac=${macAddr}
     -- set Interface ${ovsPort} external_ids:iface-status=active
     -- set Interface ${ovsPort} external_ids:iface-id=${neutronPortId}
EOF
)
    [ -z "$portVmId" ] && cmd2='' || cmd2="-- set Interface ${ovsPort} external_ids:vm-id=${portVmId}"

    # cmd="$cmd1 $cmd2 ; echo $?"
    cmd="$cmd1 $cmd2 2>&1 ; echo \$?"

    [ $DEBUG -gt 0 ] && echo -n "$callerFunction $cmd ==> "
    [ -z $DEBUG_FAKE_OVS ] && rc=$(eval $cmd) || rc=fake
    [ $DEBUG -gt 0 ] && echo "$rc" && echo

    [ "$expectedSuccess" != true ] && expectedRc=999 || expectedRc=0
    if [ "$rc" != "$expectedRc" ] && [ "$expectedRc" -eq 0 ] && [ -z $DEBUG_FAKE_OVS ]; then
	echo "ERROR: $callerFunction $cmd unexpected rc $rc (wanted $expectedRc)"
	exit 1
    fi
}

#--

function create_ext_net {
    tntId=$1 ; shift
    netId=$1 ; shift
    url="${ODL}/networks/"

    body=$(cat <<EOF
-d '{
  "network": [
    {
      "provider:physical_network": "physnetext1", 
      "port_security_enabled": true, 
      "provider:network_type": "flat", 
      "id": "${netId}",
      "provider:segmentation_id": null, 
      "router:external": true, 
      "name": "ext1", 
      "admin_state_up": true,
      "tenant_id": "${tntId}", 
      "shared": false
    }
  ]
}
'
EOF
)
    cmd="$CURL_POST $body $CURL_RETURN_FORMAT $url 2>&1" 
    do_eval_command ${FUNCNAME[0]} "$1" "$cmd"
}

#--

function create_ext_subnet {
    tntId=$1    ; shift
    netId=$1    ; shift
    subnetId=$1 ; shift
    url="${ODL}/subnets/"

    body=$(cat <<EOF
-d '{
  "subnet": {
    "name": "subext1", 
    "enable_dhcp": false, 
    "network_id": "${netId}",
    "tenant_id": "${tntId}",
    "dns_nameservers": [], 
    "gateway_ip": "192.168.111.254", 
    "ipv6_ra_mode": null, 
    "allocation_pools": [
      {
        "start": "192.168.111.21", 
        "end": "192.168.111.40"
      }
    ], 
    "host_routes": [], 
    "shared": false,
    "ip_version": 4,
    "ipv6_address_mode": null, 
    "cidr": "192.168.111.0/24", 
    "id": "${subnetId}",
    "subnetpool_id": null
  }
}
'
EOF
)
    cmd="$CURL_POST $body $CURL_RETURN_FORMAT $url 2>&1" 
    do_eval_command ${FUNCNAME[0]} "$1" "$cmd"
}

#--

function create_router {
    tntId=$1 ; shift
    rtrId=$1 ; shift
    url="${ODL}/routers/"

    body=$(cat <<EOF
-d '{
  "router": {
    "status": "ACTIVE", 
    "external_gateway_info": null, 
    "name": "rtr1", 
    "gw_port_id": null, 
    "admin_state_up": true, 
    "routes": [], 
    "tenant_id": "${tntId}", 
    "distributed": false, 
    "id": "${rtrId}"
  }
}
'
EOF
)
    cmd="$CURL_POST $body $CURL_RETURN_FORMAT $url 2>&1" 
    do_eval_command ${FUNCNAME[0]} "$1" "$cmd"
}

#--

function create_port_rtr_gateway {
    tntId=$1     ; shift
    rtrId=$1     ; shift
    netId=$1     ; shift
    subnetId=$1  ; shift
    portId=$1    ; shift
    url="${ODL}/ports/"

    body=$(cat <<EOF
-d '{
  "port": {
    "binding:host_id": "", 
    "allowed_address_pairs": [], 
    "device_owner": "network:router_gateway", 
    "port_security_enabled": false, 
    "binding:profile": {}, 
    "fixed_ips": [
      {
        "subnet_id": "${subnetId}",
        "ip_address": "192.168.111.21"
      }
    ], 
    "id": "${portId}",
    "security_groups": [], 
    "device_id": "${rtrId}",
    "name": "", 
    "admin_state_up": true, 
    "network_id": "${netId}",
    "tenant_id": "", 
    "binding:vif_details": {}, 
    "binding:vnic_type": "normal", 
    "binding:vif_type": "unbound", 
    "mac_address": "FA:16:3E:7E:A0:D8"
  }
}
'
EOF
)
    cmd="$CURL_POST $body $CURL_RETURN_FORMAT $url 2>&1" 
    do_eval_command ${FUNCNAME[0]} "$1" "$cmd"
}

#--

function update_router_port_gateway {
    tntId=$1     ; shift
    rtrId=$1     ; shift
    netId=$1     ; shift
    subnetId=$1  ; shift
    portId=$1    ; shift
    url="${ODL}/routers/${rtrId}"

    body=$(cat <<EOF
-d '{
  "router": {
    "external_gateway_info": {
      "network_id": "${netId}",
      "enable_snat": true, 
      "external_fixed_ips": [
        {
          "subnet_id": "${subnetId}",
          "ip_address": "192.168.111.21"
        }
      ]
    }, 
    "name": "rtr1", 
    "gw_port_id": "${portId}",
    "admin_state_up": true, 
    "distributed": false, 
    "routes": []
  }
}'
EOF
)
    cmd="$CURL_PUT $body $CURL_RETURN_FORMAT $url 2>&1" 
    [ -z "$1" ] && expectedRc=200 || expectedRc=$1
    do_eval_command ${FUNCNAME[0]} $expectedRc "$cmd"
}

#--

function create_tnt_net {
    tntId=$1    ; shift
    netName=$1  ; shift
    netId=$1    ; shift
    netSegm=$1  ; shift
    url="${ODL}/networks/"

    body=$(cat <<EOF
-d '{
  "network": {
    "name": "${netName}", 
    "provider:physical_network": null, 
    "router:external": false, 
    "tenant_id": "${tntId}", 
    "admin_state_up": true, 
    "provider:network_type": "vxlan", 
    "shared": false, 
    "port_security_enabled": true, 
    "id": "${netId}",
    "provider:segmentation_id": ${netSegm}
  }
}
'
EOF
)
    cmd="$CURL_POST $body $CURL_RETURN_FORMAT $url 2>&1" 
    do_eval_command ${FUNCNAME[0]} "$1" "$cmd"
}

#--

function create_tnt_subnet {
    tntId=$1       ; shift
    subnetName=$1  ; shift
    netId=$1       ; shift
    subnetId=$1    ; shift
    url="${ODL}/subnets/"

    body=$(cat <<EOF
-d '
{
  "subnet": {
    "name": "${subnetName}", 
    "enable_dhcp": true, 
    "network_id": "${netId}",
    "tenant_id": "${tntId}",
    "dns_nameservers": [
      "192.168.111.254"
    ], 
    "gateway_ip": "10.1.0.1", 
    "ipv6_ra_mode": null, 
    "allocation_pools": [
      {
        "start": "10.1.0.2", 
        "end": "10.1.0.254"
      }
    ], 
    "host_routes": [], 
    "shared": false, 
    "ip_version": 4, 
    "ipv6_address_mode": null, 
    "cidr": "10.1.0.0/24", 
    "id": "$subnetId",
    "subnetpool_id": null
  }
}
'
EOF
)
    cmd="$CURL_POST $body $CURL_RETURN_FORMAT $url 2>&1" 
    do_eval_command ${FUNCNAME[0]} "$1" "$cmd"
}

#--

function create_port_dhcp {
    # ${TNT1_ID} ${TNT1_NET1_ID} ${TNT1_SUBNET1_ID} ${TNT1_NET1_DHCP_PORT_ID} ${TNT1_NET1_DHCP_MAC} ${TNT1_NET1_DHCP_DEVICE_ID}
    tntId=$1        ; shift
    netId=$1        ; shift
    subnetId=$1     ; shift
    dhcpId=$1       ; shift
    dhcpMac=$1      ; shift
    dhcpDeviceId=$1 ; shift
    url="${ODL}/ports/"

    body=$(cat <<EOF
-d '
{
  "port": {
    "binding:host_id": "${BIND_HOST_ID}", 
    "allowed_address_pairs": [], 
    "device_owner": "network:dhcp", 
    "port_security_enabled": false, 
    "binding:profile": {}, 
    "fixed_ips": [
      {
        "subnet_id": "${subnetId}",
        "ip_address": "10.1.0.2"
      }
    ], 
    "id": "${dhcpId}",
    "security_groups": [], 
    "device_id": "${dhcpDeviceId}",
    "name": "", 
    "admin_state_up": true, 
    "network_id": "${netId}",
    "tenant_id": "${tntId}",
    "binding:vif_details": {}, 
    "binding:vnic_type": "normal", 
    "binding:vif_type": "unbound", 
    "mac_address": "${dhcpMac}"
  }
}'
EOF
)
    cmd="$CURL_POST $body $CURL_RETURN_FORMAT $url 2>&1" 
    do_eval_command ${FUNCNAME[0]} "$1" "$cmd"
}

#--

function update_port_dhcp {
    portId=$1    ; shift
    dhcpDeviceId=$1 ; shift
    url="${ODL}/ports/${portId}"

    body=$(cat <<EOF
-d '
{
"port": {
    "binding:host_id": "${BIND_HOST_ID}", 
    "allowed_address_pairs": [], 
    "extra_dhcp_opts": [], 
    "device_owner": "network:dhcp", 
    "binding:profile": {}, 
    "port_security_enabled": false, 
    "security_groups": [], 
    "device_id": "${dhcpDeviceId}",
    "name": "", 
    "admin_state_up": true, 
    "binding:vif_details": {
      "port_filter": true
    }, 
    "binding:vnic_type": "normal", 
    "binding:vif_type": "ovs"
  }
}
'
EOF
)
    cmd="$CURL_PUT $body $CURL_RETURN_FORMAT $url 2>&1" 
    [ -z "$1" ] && expectedRc=200 || expectedRc=$1
    do_eval_command ${FUNCNAME[0]} $expectedRc "$cmd"
}

#--

function create_port_rtr_interface {
    tntId=$1    ; shift
    rtrId=$1    ; shift
    netId=$1    ; shift
    subnetId=$1 ; shift
    portId=$1   ; shift
    url="${ODL}/ports/"

    body=$(cat <<EOF
-d '{
  "port": {
    "binding:host_id": "", 
    "allowed_address_pairs": [], 
    "device_owner": "network:router_interface", 
    "port_security_enabled": false, 
    "binding:profile": {}, 
    "fixed_ips": [
      {
        "subnet_id": "${subnetId}",
        "ip_address": "10.1.0.1"
      }
    ], 
    "id": "${portId}",
    "security_groups": [], 
    "device_id": "${rtrId}",
    "name": "", 
    "admin_state_up": true, 
    "network_id": "${netId}",
    "tenant_id": "${tntId}",
    "binding:vif_details": {}, 
    "binding:vnic_type": "normal", 
    "binding:vif_type": "unbound", 
    "mac_address": "FA:16:3E:C0:BD:8B"
  }
}
'
EOF
)
    cmd="$CURL_POST $body $CURL_RETURN_FORMAT $url 2>&1" 
    do_eval_command ${FUNCNAME[0]} "$1" "$cmd"
}

#--

function update_router_interface {
    # ${TNT1_ID} ${TNT1_RTR_ID} ${TNT1_SUBNET1_ID} ${NEUTRON_PORT_TNT1_RTR_NET1}
    tntId=$1     ; shift
    rtrId=$1     ; shift
    subnetId=$1  ; shift
    portId=$1    ; shift
    url="${ODL}/routers/${rtrId}/add_router_interface"

    body=$(cat <<EOF
-d '{
  "subnet_id": "${subnetId}",
  "tenant_id": "${tntId}",
  "port_id": "${portId}",
  "id": "${rtrId}"
}'
EOF
)
    cmd="$CURL_PUT $body $CURL_RETURN_FORMAT $url 2>&1" 
    [ -z "$1" ] && expectedRc=200 || expectedRc=$1
    do_eval_command ${FUNCNAME[0]} $expectedRc "$cmd"
}

#--

function create_port_vm {
    # ${TNT1_ID} ${TNT1_NET1_ID} ${TNT1_SUBNET1_ID} ${TNT1_VM1_PORT_ID} ${TNT1_VM1_MAC} ${TNT1_VM1_DEVICE_ID}
    tntId=$1      ; shift
    netId=$1      ; shift
    subnetId=$1   ; shift
    portId=$1     ; shift
    macAddr=$1 ; shift
    deviceId=$1   ; shift
    url="${ODL}/ports/"

    secGroupId='970d6a6d-bebf-43a3-85cc-a860fc994333'

    body=$(cat <<EOF
-d '{
  "port": {
    "binding:host_id": "${BIND_HOST_ID}", 
    "allowed_address_pairs": [], 
    "device_owner": "compute:None", 
    "port_security_enabled": true, 
    "binding:profile": {}, 
    "fixed_ips": [
      {
        "subnet_id": "${subnetId}",
        "ip_address": "10.1.0.3"
      }
    ], 
    "id": "${portId}",
    "security_groups": [
      {
        "tenant_id": "${tntId}", 
        "description": "Default security group", 
        "id": "${secGroupId}", 
        "security_group_rules": [
          {
            "remote_group_id": null, 
            "direction": "egress", 
            "remote_ip_prefix": null, 
            "protocol": null, 
            "ethertype": "IPv4", 
            "tenant_id": "${tntId}", 
            "port_range_max": null, 
            "port_range_min": null, 
            "id": "3f260b84-637a-4edc-8ba6-a5ff36b2ae79", 
            "security_group_id": "${secGroupId}"
          }, 
          {
            "remote_group_id": null, 
            "direction": "egress", 
            "remote_ip_prefix": null, 
            "protocol": null, 
            "ethertype": "IPv6", 
            "tenant_id": "${tntId}", 
            "port_range_max": null, 
            "port_range_min": null, 
            "id": "9c3a324a-822d-4a60-b4d9-bc9fc8a890e9", 
            "security_group_id": "${secGroupId}"
          }, 
          {
            "remote_group_id": "${secGroupId}", 
            "direction": "ingress", 
            "remote_ip_prefix": null, 
            "protocol": null, 
            "ethertype": "IPv6", 
            "tenant_id": "${tntId}", 
            "port_range_max": null, 
            "port_range_min": null, 
            "id": "a3dc2551-2939-4a0b-8113-bcbce704c0fd", 
            "security_group_id": "${secGroupId}"
          }, 
          {
            "remote_group_id": "${secGroupId}", 
            "direction": "ingress", 
            "remote_ip_prefix": null, 
            "protocol": null, 
            "ethertype": "IPv4", 
            "tenant_id": "${tntId}", 
            "port_range_max": null, 
            "port_range_min": null, 
            "id": "efa8f393-1494-4370-87c2-693f1c109190", 
            "security_group_id": "${secGroupId}"
          }
        ], 
        "name": "default"
      }
    ], 
    "device_id": "${deviceId}",
    "name": "", 
    "admin_state_up": true, 
    "network_id": "${netId}",
    "tenant_id": "${tntId}", 
    "binding:vif_details": {}, 
    "binding:vnic_type": "normal", 
    "binding:vif_type": "unbound", 
    "mac_address": "${macAddr}"
  }
}'
EOF
)
    cmd="$CURL_POST $body $CURL_RETURN_FORMAT $url 2>&1" 
    do_eval_command ${FUNCNAME[0]} "$1" "$cmd"
}

#--

function create_port_floating_ip {
    tntId=$1        ; shift
    netId=$1        ; shift
    subnetId=$1     ; shift
    portId=$1       ; shift
    macAddress=$1   ; shift
    deviceId=$1     ; shift
    url="${ODL}/ports/"

    body=$(cat <<EOF
-d '
{
  "port": {
    "binding:host_id": "", 
    "allowed_address_pairs": [], 
    "device_owner": "network:floatingip", 
    "port_security_enabled": false, 
    "binding:profile": {}, 
    "fixed_ips": [
      {
        "subnet_id": "${subnetId}",
        "ip_address": "192.168.111.22"
      }
    ], 
    "id": "${portId}",
    "security_groups": [], 
    "device_id": "${deviceId}",
    "name": "", 
    "admin_state_up": true, 
    "network_id": "${netId}",
    "tenant_id": "", 
    "binding:vif_details": {}, 
    "binding:vnic_type": "normal", 
    "binding:vif_type": "unbound", 
    "mac_address": "${macAddress}"
  }
}'
EOF
)
    cmd="$CURL_POST $body $CURL_RETURN_FORMAT $url 2>&1" 
    do_eval_command ${FUNCNAME[0]} "$1" "$cmd"
}

#--

function create_floating_ip {
    tntId=$1          ; shift
    netId=$1          ; shift
    floatIpId=$1      ; shift
    floatIpAddress=$1 ; shift
    url="${ODL}/floatingips/"

    body=$(cat <<EOF
-d '{
  "floatingip": {
    "floating_network_id": "${netId}",
    "router_id": null, 
    "fixed_ip_address": null, 
    "floating_ip_address": "${floatIpAddress}",
    "tenant_id": "${tntId}",
    "status": "ACTIVE", 
    "port_id": null, 
    "id": "${floatIpId}"
  }
}'
EOF
)
    cmd="$CURL_POST $body $CURL_RETURN_FORMAT $url 2>&1" 
    do_eval_command ${FUNCNAME[0]} "$1" "$cmd"
}

#--

function associate_floating_ip {
    # ${TNT1_ID} ${TNT1_RTR_ID} ${FLOAT_IP1_ID} ${FLOAT_IP1_ADDRESS} ${TNT1_VM1_PORT_ID}
    tntId=$1          ; shift
    netId=$1          ; shift
    rtrId=$1          ; shift
    floatIpId=$1      ; shift
    floatIpAddress=$1 ; shift
    vmPortId=$1       ; shift
    url="${ODL}/floatingips/${floatIpId}"

    body=$(cat <<EOF
-d '{
  "floatingip": {
    "floating_network_id": "${netId}",
    "router_id": "${rtrId}",
    "fixed_ip_address": "10.1.0.3", 
    "floating_ip_address": "${floatIpAddress}",
    "tenant_id": "${tntId}",
    "status": "ACTIVE", 
    "port_id": "${vmPortId}",
    "id": "${floatIpId}"
  }
}'
EOF
)
    cmd="$CURL_PUT $body $CURL_RETURN_FORMAT $url 2>&1" 
    [ -z "$1" ] && expectedRc=200 || expectedRc=$1
    do_eval_command ${FUNCNAME[0]} $expectedRc "$cmd"
}

#--

if [ -z "" ]; then
    # setup_ovs
    check_get_code networks/
    check_get_code networksbad/ 404
    create_ext_net ${TNT1_ID} ${EXT_NET1_ID} 
    create_ext_subnet ${TNT1_ID} ${EXT_NET1_ID} ${EXT_SUBNET1_ID} 201
    create_ext_subnet ${TNT1_ID} ${EXT_NET1_ID} ${EXT_SUBNET1_ID} 400
    create_router ${TNT1_ID} ${TNT1_RTR_ID}
    create_router ${TNT1_ID} ${TNT1_RTR_ID} 400
    create_port_rtr_gateway ${TNT1_ID} ${TNT1_RTR_ID} ${EXT_NET1_ID} ${EXT_SUBNET1_ID} ${NEUTRON_PORT_TNT1_RTR_GW}
    create_port_rtr_gateway ${TNT1_ID} ${TNT1_RTR_ID} ${EXT_NET1_ID} ${EXT_SUBNET1_ID} ${NEUTRON_PORT_TNT1_RTR_GW} 400
    update_router_port_gateway ${TNT1_ID} ${TNT1_RTR_ID} ${EXT_NET1_ID} ${EXT_SUBNET1_ID} ${NEUTRON_PORT_TNT1_RTR_GW}
    create_tnt_net ${TNT1_ID} ${TNT1_NET1_NAME} ${TNT1_NET1_ID} ${TNT1_NET1_SEGM}
    create_tnt_net ${TNT1_ID} ${TNT1_NET1_NAME} ${TNT1_NET1_ID} ${TNT1_NET1_SEGM} 400
    create_tnt_subnet ${TNT1_ID} ${TNT1_SUBNET1_NAME} ${TNT1_NET1_ID} ${TNT1_SUBNET1_ID}
    create_tnt_subnet ${TNT1_ID} ${TNT1_SUBNET1_NAME} ${TNT1_NET1_ID} ${TNT1_SUBNET1_ID} 400
    create_port_dhcp ${TNT1_ID} ${TNT1_NET1_ID} ${TNT1_SUBNET1_ID} ${TNT1_NET1_DHCP_PORT_ID} ${TNT1_NET1_DHCP_MAC} ${TNT1_NET1_DHCP_DEVICE_ID}
    create_ovs_port create_ovs_port_for_dhcp_net1 true  ${TNT1_NET1_DHCP_OVS_PORT} ${TNT1_NET1_DHCP_MAC} ${TNT1_NET1_DHCP_PORT_ID}
    create_ovs_port create_ovs_port_for_dhcp_net1 false ${TNT1_NET1_DHCP_OVS_PORT} ${TNT1_NET1_DHCP_MAC} ${TNT1_NET1_DHCP_PORT_ID}
    update_port_dhcp ${TNT1_NET1_DHCP_PORT_ID} ${TNT1_NET1_DHCP_DEVICE_ID}
    create_port_rtr_interface ${TNT1_ID} ${TNT1_RTR_ID} ${TNT1_NET1_ID} ${TNT1_SUBNET1_ID} ${NEUTRON_PORT_TNT1_RTR_NET1}
    create_port_rtr_interface ${TNT1_ID} ${TNT1_RTR_ID} ${TNT1_NET1_ID} ${TNT1_SUBNET1_ID} ${NEUTRON_PORT_TNT1_RTR_NET1} 400
    update_router_interface ${TNT1_ID} ${TNT1_RTR_ID} ${TNT1_SUBNET1_ID} ${NEUTRON_PORT_TNT1_RTR_NET1}
    create_port_vm ${TNT1_ID} ${TNT1_NET1_ID} ${TNT1_SUBNET1_ID} ${TNT1_VM1_PORT_ID} ${TNT1_VM1_MAC} ${TNT1_VM1_DEVICE_ID}
    create_port_vm ${TNT1_ID} ${TNT1_NET1_ID} ${TNT1_SUBNET1_ID} ${TNT1_VM1_PORT_ID} ${TNT1_VM1_MAC} ${TNT1_VM1_DEVICE_ID} 400
    create_ovs_port create_ovs_port_for_vm1 true  ${TNT1_NET1_VM1_OVS_PORT} ${TNT1_VM1_MAC} ${TNT1_VM1_PORT_ID} ${TNT1_VM1_VM_ID}
    create_port_floating_ip "" ${EXT_NET1_ID} ${EXT_SUBNET1_ID} ${FLOAT_IP1_PORT_ID} ${FLOAT_IP1_MAC} ${FLOAT_IP1_DEVICE_ID}
    create_floating_ip ${TNT1_ID} ${EXT_NET1_ID} ${FLOAT_IP1_ID} ${FLOAT_IP1_ADDRESS}
    associate_floating_ip ${TNT1_ID} ${EXT_NET1_ID} ${TNT1_RTR_ID} ${FLOAT_IP1_ID} ${FLOAT_IP1_ADDRESS} ${TNT1_VM1_PORT_ID}
else
    export DEBUG_FAKE_POST=yes ; export DEBUG_FAKE_OVS=yes ; echo testing
    # associate_floating_ip ${TNT1_ID} ${EXT_NET1_ID} ${TNT1_RTR_ID} ${FLOAT_IP1_ID} ${FLOAT_IP1_ADDRESS} ${TNT1_VM1_PORT_ID}
fi

echo ok
