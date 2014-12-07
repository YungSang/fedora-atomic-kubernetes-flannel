#!/bin/sh

ADDR="%ADDR%"
ETCD_DISCVERY="%ETCD_DISCVERY%"
MINION_IP_ADDRS="%MINION_IP_ADDRS%"

cd /tmp
curl -OLs https://github.com/coreos/etcd/releases/download/v0.4.6/etcd-v0.4.6-linux-amd64.tar.gz
tar zxvf etcd-v0.4.6-linux-amd64.tar.gz
cp etcd-v0.4.6-linux-amd64/etcdctl /opt/bin

cat <<EOF > /etc/systemd/system/etcd.service
[Unit]
Description=etcd

[Service]
Environment=ETCD_DATA_DIR=/var/lib/etcd
Environment=ETCD_NAME=%m
ExecStart=/usr/bin/etcd \
  -addr=${ADDR}:4001 \
  -peer-addr=${ADDR}:7001 \
  -discovery=http://${ETCD_DISCVERY}:4001/v2/keys/cluster
Restart=always
RestartSec=10
EOF
systemctl daemon-reload
systemctl start etcd.service

cat <<EOF > /etc/systemd/system/flannel.service
[Unit]
Requires=etcd.service
After=etcd.service

[Service]
ExecStartPre=/opt/bin/etcdctl set /coreos.com/network/config '{"Network":"10.100.0.0/16"}'
ExecStart=/opt/bin/flanneld -iface=${ADDR}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable flannel.service
systemctl start flannel.service

systemctl disable docker.service
cat <<EOF > /etc/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target docker.socket flannel.service
Requires=docker.socket flannel.service

[Service]
Type=notify
WorkingDirectory=/etc
EnvironmentFile=-/etc/sysconfig/docker
EnvironmentFile=-/etc/sysconfig/docker-storage
EnvironmentFile=/run/flannel/subnet.env
ExecStartPre=-/usr/sbin/ip link set dev docker0 down
ExecStartPre=-/usr/sbin/ip link del dev docker0
ExecStart=/usr/bin/docker -d -H fd:// \$OPTIONS \$DOCKER_STORAGE_OPTIONS \
  --bip=\${FLANNEL_SUBNET} \
  --mtu=\${FLANNEL_MTU}
LimitNOFILE=1048576
LimitNPROC=1048576
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable docker.service
systemctl restart docker.service

iptables -I INPUT 1 -p tcp --dport 8080 -j ACCEPT -m comment --comment "kube-apiserver"

cat <<EOF > /etc/systemd/system/kube-apiserver.service
[Unit]
ConditionFileIsExecutable=/usr/bin/kube-apiserver
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Wants=etcd.service
After=etcd.service

[Service]
ExecStart=/usr/bin/kube-apiserver \
  -address=127.0.0.1 \
  -port=8080 \
  -etcd_servers=http://127.0.0.1:4001 \
  -portal_net=10.100.0.0/16 \
  -logtostderr=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-apiserver.service
systemctl start kube-apiserver.service

cat <<EOF > /etc/systemd/system/kube-scheduler.service
[Unit]
ConditionFileIsExecutable=/usr/bin/kube-scheduler
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Wants=kube-apiserver.service
After=kube-apiserver.service

[Service]
ExecStart=/usr/bin/kube-scheduler \
  -logtostderr=true \
  -master=127.0.0.1:8080
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-scheduler.service
systemctl start kube-scheduler.service

cat <<EOF > /etc/systemd/system/kube-controller-manager.service
[Unit]
ConditionFileIsExecutable=/usr/bin/kube-controller-manager
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Wants=etcd.service
After=etcd.service

[Service]
ExecStart=/usr/bin/kube-controller-manager \
  -master=127.0.0.1:8080 \
  -machines=${MINION_IP_ADDRS} \
  -logtostderr=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-controller-manager.service
systemctl start kube-controller-manager.service
