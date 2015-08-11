#!/usr/bin/env bash
# This bootstraps Puppet on CentOS 7.x
# It has been tested on CentOS 7.0 64bit

set -e

REPO_URL="http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm"

if [ "$EUID" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

if which puppet > /dev/null 2>&1; then
  echo "Puppet is already installed."
  exit 0
fi

# Install puppet labs repo
echo "Configuring PuppetLabs repo..."
repo_path=$(mktemp)
wget --output-document="${repo_path}" "${REPO_URL}" 2>/dev/null
rpm -i "${repo_path}" >/dev/null

# Install Puppet...
echo "Installing puppet"
yum install -y puppet > /dev/null

echo "Puppet installed!"

# Installing Puppet Modules
puppet module install puppetlabs/vcsrepo
puppet module install puppetlabs/stdlib

# Setting root access
echo "root:vagrant"|chpasswd
cat /etc/ssh/sshd_config > /etc/ssh/sshd_config.orig
sed -i -r -e 's/^#*\s*(PermitRootLogin)\s.*$/\1 yes/' /etc/ssh/sshd_config

# Disable selinux to avoid any problems
setenforce 0
sed -i -e 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config

# Use iptables instead of firewalld since that is what OpenStack uses.
# Remove firewalld since devstack has a bug that will reenable it
systemctl stop firewalld.service
yum remove -y firewalld
yum install -y iptables-services
touch /etc/sysconfig/iptables
systemctl enable iptables.service
systemctl start iptables.service
