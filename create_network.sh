#!/bin/bash

source functions
source_rc setup.cfg
source_rc overcloudrc


function add_router_interface {
  startlog "Adding interface to router"
  neutron router-interface-add router1 private-subnet 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function create_router {
  startlog "Creating router"
  neutron router-create router1 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}

function create_ext_network {
  startlog "Creating external network"
  neutron net-create ext-net --router:external True --provider:physical_network datacentre --provider:network_type flat 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
  return $rc
}

function create_ext_subnet {
  startlog "Creating external subnet"
  neutron subnet-create --name ext-subnet --allocation-pool start=10.107.151.221,end=10.107.151.240 --dns-nameserver 8.8.8.8 --disable-dhcp $gwarg ext-net 10.107.151.0/24 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
  fi
	return $rc
}

function set_external_gateway {
  startlog "Setting external gateway"
  neutron router-gateway-set router1 ext-net 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function create_private_network {
  startlog "Creating private network"
  neutron net-create private-net --provider:network_type vlan --provider:physical_network datacentre 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

function create_private_subnet {
  startlog "Creating private subnet"
  neutron subnet-create private-net --name private-subnet --enable_dhcp=True --allocation-pool=start=172.17.26.11,end=172.17.26.50 172.17.26.0/24 2>>$stderr 1>>$stdout
  rc=$?
  if [ $rc -eq 0 ]; then
    endlog "done"
  else
    endlog "error"
    rc=255
  fi
  return $rc
}

if [ ! -z "$gw" ]; then
  gwarg="--gateway $gw"
else
  gwarg=""
fi

rc=0

neutron router-list 2>>$stderr 2>>$stderr | grep -q router1
if [ $? -ne 0 ]; then
  create_router
  rc=$?
fi

if [ $rc -eq 0 ]; then
  neutron net-list 2>>$stderr | grep -q ext-net
  if [ $? -ne 0 ]; then
     create_ext_network
     rc=$?
  fi
fi

if [ $rc -eq 0 ]; then
  neutron subnet-list 2>>$stderr | grep -q ext-subnet
  if [ $? -ne 0 ]; then
     create_ext_subnet
     rc=$?
  fi
fi

if [ $rc -eq 0 ]; then
  neutron router-show router1 2>>$stderr | grep gateway | grep -q ip_address
  if [ $? -ne 0 ]; then
    set_external_gateway
    rc=$?
  fi
fi

if [ $rc -eq 0 ]; then
  neutron net-list 2>>$stderr | grep -q private
  if [ $? -ne 0 ]; then
    create_private_network
    rc=$?
  fi
fi

if [ $rc -eq 0 ]; then
  neutron subnet-list 2>>$stderr | grep -q private-subnet
  if [ $? -ne 0 ]; then
    create_private_subnet
    rc=$?
  fi
fi

if [ $rc -eq 0 ]; then
  neutron router-port-list router1 2>>$stderr | grep -q 10.254.
  if [ $? -ne 0 ]; then
    add_router_interface
    rc=$?
  fi
fi

exit $rc
