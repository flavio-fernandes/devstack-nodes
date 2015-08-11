#!/usr/bin/env bash
set -e
wget -O ./bootstrap.sh https://raw.githubusercontent.com/flavio-fernandes/puppet-bootstrap/master/centos_7_x.sh
chmod 755 ./bootstrap.sh

cat <<EOT >> ./bootstrap.sh

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
EOT
