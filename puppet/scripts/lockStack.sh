#!/usr/bin/env bash

cp --no-clobber /opt/devstack/local.conf{,.orig}
sed -i -r -e 's/^#*\s*(OFFLINE=).*$/\1True/' /opt/devstack/local.conf
sed -i -r -e 's/^#*\s*(RECLONE=).*$/\1no/' /opt/devstack/local.conf

