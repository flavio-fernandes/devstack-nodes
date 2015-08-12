#!/usr/bin/env bash

cp --no-clobber /home/vagrant/devstack/local.conf{,.orig}
sed -i -r -e 's/^#*\s*(OFFLINE=).*$/\1True/' /home/vagrant/devstack/local.conf
sed -i -r -e 's/^#*\s*(RECLONE=).*$/\1no/' /home/vagrant/devstack/local.conf

