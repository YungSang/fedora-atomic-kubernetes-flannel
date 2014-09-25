#!/bin/sh

ADDR="%ADDR%"

cd /tmp
curl -OLs https://github.com/coreos/etcd/releases/download/v0.4.6/etcd-v0.4.6-linux-amd64.tar.gz
tar zxvf etcd-v0.4.6-linux-amd64.tar.gz
cp etcd-v0.4.6-linux-amd64/etcd /opt/bin
cp etcd-v0.4.6-linux-amd64/etcdctl /opt/bin

cat <<EOF > /etc/systemd/system/etcd.service
[Unit]
Description=etcd

[Service]
Environment=ETCD_DATA_DIR=/var/lib/etcd
Environment=ETCD_NAME=%m
ExecStart=/opt/bin/etcd \
  -addr=${ADDR}:4001 \
  -peer-addr=${ADDR}:7001
Restart=always
RestartSec=10s
EOF
systemctl daemon-reload
systemctl start etcd.service
