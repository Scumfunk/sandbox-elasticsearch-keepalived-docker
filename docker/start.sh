#!/bin/bash

keepalived --dont-fork --dump-conf --vrrp -f /etc/keepalived/keepalived.conf &
source /usr/local/bin/docker-entrypoint.sh