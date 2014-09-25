#!/bin/sh

ADDR="%ADDR%"
ETCD_DISCVERY="%ETCD_DISCVERY%"
MINION_IP_ADDRS="%MINION_IP_ADDRS%"

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

cat <<EOF > /etc/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io
Requires=flannel.service
After=flannel.service

[Service]
EnvironmentFile=/run/flannel/subnet.env
ExecStartPre=-/usr/sbin/ip link set dev docker0 down
ExecStartPre=-/usr/sbin/ip link del dev docker0
ExecStart=/usr/bin/docker -d -H fd:// --selinux-enabled --storage-opt dm.fs=xfs --bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable docker.service
systemctl restart docker.service

cat <<EOF > /etc/systemd/system/download-kubernetes.service
[Unit]
Before=apiserver.service
Before=controller-manager.service
Description=Download Kubernetes Binaries
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/curl -Ls http://storage.googleapis.com/kubernetes/apiserver -o /opt/bin/apiserver
ExecStart=/usr/bin/curl -Ls http://storage.googleapis.com/kubernetes/controller-manager -o /opt/bin/controller-manager
ExecStart=/usr/bin/curl -Ls http://storage.googleapis.com/kubernetes/kubecfg -o /opt/bin/kubecfg
ExecStart=/usr/bin/curl -Ls http://storage.googleapis.com/kubernetes/scheduler -o /opt/bin/scheduler
ExecStart=/usr/bin/chmod +x /opt/bin/apiserver
ExecStart=/usr/bin/chmod +x /opt/bin/controller-manager
ExecStart=/usr/bin/chmod +x /opt/bin/kubecfg
ExecStart=/usr/bin/chmod +x /opt/bin/scheduler
RemainAfterExit=yes
Type=oneshot
EOF
systemctl daemon-reload
systemctl start download-kubernetes.service

iptables -I INPUT 1 -p tcp --dport 8080 -j ACCEPT -m comment --comment "kube-apiserver"

cat <<EOF > /etc/systemd/system/apiserver.service
[Unit]
After=etcd.service
After=download-kubernetes.service
ConditionFileIsExecutable=/opt/bin/apiserver
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Wants=etcd.service
Wants=download-kubernetes.service

[Service]
ExecStart=/opt/bin/apiserver \
  --address=127.0.0.1 \
  --port=8080 \
  --etcd_servers=http://127.0.0.1:4001 \
  --machines=${MINION_IP_ADDRS} \
  --logtostderr=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable apiserver.service
systemctl start apiserver.service

cat <<EOF > /etc/systemd/system/scheduler.service
[Unit]
After=apiserver.service
ConditionFileIsExecutable=/opt/bin/scheduler
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Wants=apiserver.service

[Service]
ExecStart=/opt/bin/scheduler \
  --logtostderr=true \
  --master=127.0.0.1:8080
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable scheduler.service
systemctl start scheduler.service

cat <<EOF > /etc/systemd/system/controller-manager.service
[Unit]
After=etcd.service
After=download-kubernetes.service
ConditionFileIsExecutable=/opt/bin/controller-manager
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Wants=etcd.service
Wants=download-kubernetes.service

[Service]
ExecStart=/opt/bin/controller-manager \
  --master=127.0.0.1:8080 \
  --logtostderr=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable controller-manager.service
systemctl start controller-manager.service
