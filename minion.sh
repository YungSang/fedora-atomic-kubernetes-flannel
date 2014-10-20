#!/bin/sh

ADDR="%ADDR%"
ETCD_DISCVERY="%ETCD_DISCVERY%"

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
RestartSec=10s
EOF
systemctl daemon-reload
systemctl start etcd.service

cat <<EOF > /etc/systemd/system/flannel.service
[Unit]
Requires=etcd.service
After=etcd.service

[Service]
ExecStart=/opt/bin/flanneld -iface=${ADDR}

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
Documentation=http://docs.docker.io
Requires=flannel.service
After=flannel.service

[Service]
EnvironmentFile=/run/flannel/subnet.env
ExecStartPre=-/usr/sbin/ip link set dev docker0 down
ExecStartPre=-/usr/sbin/ip link del dev docker0
ExecStart=/usr/bin/docker -d -H fd:// --selinux-enabled --bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable docker.service
systemctl restart docker.service

iptables -I INPUT 1 -p tcp --dport 10250 -j ACCEPT -m comment --comment "kubelet"

cat <<EOF > /etc/systemd/system/kubelet.service
[Unit]
ConditionFileIsExecutable=/usr/bin/kubelet
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Wants=etcd.service
After=etcd.service

[Service]
ExecStart=/usr/bin/kubelet \
  --address=0.0.0.0 \
  --port=10250 \
  --hostname_override=${ADDR} \
  --etcd_servers=http://127.0.0.1:4001 \
  --logtostderr=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kubelet.service
systemctl start kubelet.service

cat <<EOF > /etc/systemd/system/kube-proxy.service
[Unit]
ConditionFileIsExecutable=/usr/bin/kube-proxy
Description=Kubernetes Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Wants=etcd.service
After=etcd.service

[Service]
ExecStart=/usr/bin/kube-proxy --etcd_servers=http://127.0.0.1:4001 --logtostderr=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable kube-proxy.service
systemctl start kube-proxy.service
