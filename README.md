# Running Kubernetes Example on Fedora Atomic with flannel

It works same as [Running Kubernetes Example on CoreOS, Part 2 with flannel (formerly Rudder)](https://gist.github.com/YungSang/6177b69f1754f0590dbe).

# Step Zero: Build up a Kubernetes cluster

```
$ git clone https://gist.github.com/817b4bf78b58773ccfd8.git
$ vagrant up
```

It will boot up one for etcd `discovery`, one `master` and two minion servers (`minion-x`).

### Setup an SSH tunnel

Setup an SSH tunnel to the Kubernetes API Server in order to use `kubecfg` on your local machine.

```
$ curl -OL https://github.com/GoogleCloudPlatform/kubernetes/releases/download/v0.4.3/kubernetes.tar.gz
$ tar zxvf kubernetes.tar.gz kubernetes/platforms/darwin/amd64/kubecfg
x ./kubernetes/platforms/darwin/amd64/kubecfg
$ cp ./kubernetes/platforms/darwin/amd64/kubecfg /usr/local/bin
$ kubecfg -version
Kubernetes v0.4.3
```

```
$ vagrant ssh-config master > ssh.config
$ ssh -f -nNT -L 8080:127.0.0.1:8080 -F ssh.config master
$ kubecfg list pods
ID                  Image(s)            Host                Labels              Status
----------          ----------          ----------          ----------          ----------

```

### Step One to Five: same as CoreOS
[Running Kubernetes Example on CoreOS, Part 2 with flannel (formerly Rudder)](https://gist.github.com/YungSang/6177b69f1754f0590dbe)

```
$ open http://192.168.12.11:8000
$ open http://192.168.12.12:8000
```
