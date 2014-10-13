#!/bin/sh

ADDR="%ADDR%"

cat <<EOF > /etc/systemd/system/etcd.service
[Unit]
Description=etcd

[Service]
Environment=ETCD_DATA_DIR=/var/lib/etcd
Environment=ETCD_NAME=%m
ExecStart=/usr/bin/etcd \
  -addr=${ADDR}:4001 \
  -peer-addr=${ADDR}:7001
Restart=always
RestartSec=10s
EOF
systemctl daemon-reload
systemctl start etcd.service
