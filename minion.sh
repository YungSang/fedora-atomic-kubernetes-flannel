#!/bin/sh

ADDR="%ADDR%"
ETCD_DISCVERY="%ETCD_DISCVERY%"

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
ExecStart=/usr/bin/curl -Ls http://storage.googleapis.com/kubernetes/kubelet -o /opt/bin/kubelet
ExecStart=/usr/bin/curl -Ls http://storage.googleapis.com/kubernetes/proxy -o /opt/bin/proxy
ExecStart=/usr/bin/chmod +x /opt/bin/kubelet
ExecStart=/usr/bin/chmod +x /opt/bin/proxy
RemainAfterExit=yes
Type=oneshot
EOF
systemctl daemon-reload
systemctl start download-kubernetes.service

iptables -I INPUT 1 -p tcp --dport 10250 -j ACCEPT -m comment --comment "kubelet"

cat <<EOF > /etc/systemd/system/kubelet.service
[Unit]
After=etcd.service
After=download-kubernetes.service
ConditionFileIsExecutable=/opt/bin/kubelet
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Wants=etcd.service
Wants=download-kubernetes.service

[Service]
ExecStart=/opt/bin/kubelet \
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

cat <<EOF > /etc/systemd/system/proxy.service
[Unit]
After=etcd.service
After=download-kubernetes.service
ConditionFileIsExecutable=/opt/bin/proxy
Description=Kubernetes Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Wants=etcd.service
Wants=download-kubernetes.service

[Service]
ExecStart=/opt/bin/proxy --etcd_servers=http://127.0.0.1:4001 --logtostderr=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable proxy.service
systemctl start proxy.service
