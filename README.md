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
$ curl -OL https://github.com/GoogleCloudPlatform/kubernetes/releases/download/v0.4/kubernetes.tar.gz
$ tar zxvf kubernetes.tar.gz kubernetes/platforms/darwin/amd64/kubecfg
x ./kubernetes/platforms/darwin/amd64/kubecfg
$ cp ./kubernetes/platforms/darwin/amd64/kubecfg /usr/local/bin
$ kubecfg --version
Kubernetes v0.4
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

### Step Six: You have to patch a Redis server as below.

1. SSH to the minion which has redis-master. (ex. minion-2)
2. nsenter to the redis container. (ex. d244e657597a)
3. run redis-cli and set `stop-writes-on-bgsave-error no`

```
$ kubecfg list pods
ID                                     Image(s)                   Host                Labels                                                       Status
----------                             ----------                 ----------          ----------                                                   ----------
redis-master-2                         dockerfile/redis           192.168.12.12/      name=redis-master                                            Running
e02545c0-44ab-11e4-9dbf-080027825feb   brendanburns/redis-slave   192.168.12.12/      name=redisslave,replicationController=redisSlaveController   Running
e0256959-44ab-11e4-9dbf-080027825feb   brendanburns/redis-slave   192.168.12.11/      name=redisslave,replicationController=redisSlaveController   Running
1e6db043-44ae-11e4-9dbf-080027825feb   brendanburns/php-redis     192.168.12.11/      name=frontend,replicationController=frontendController       Running
1e6def33-44ae-11e4-9dbf-080027825feb   brendanburns/php-redis     192.168.12.12/      name=frontend,replicationController=frontendController       Running
$ vagrant ssh minion-2
[vagrant@minion-2 ~]$ docker ps
CONTAINER ID        IMAGE                             COMMAND                CREATED             STATUS              PORTS                    NAMES
2466045838b9        brendanburns/php-redis:latest     "/bin/sh -c /run.sh"   18 minutes ago      Up 18 minutes                                k8s--php_-_redis.a3f88088--1e6def33_-_44ae_-_11e4_-_9dbf_-_080027825feb.etcd--1e6def33_-_44ae_-_11e4_-_9dbf_-_080027825feb--3d01590a
eb6cbe73594f        kubernetes/pause:latest           "/pause"               31 minutes ago      Up 31 minutes       0.0.0.0:8000->80/tcp     k8s--net.a2367cdc--1e6def33_-_44ae_-_11e4_-_9dbf_-_080027825feb.etcd--1e6def33_-_44ae_-_11e4_-_9dbf_-_080027825feb--e85323e3
1376ebae4acd        brendanburns/redis-slave:latest   "/bin/sh -c /run.sh"   35 minutes ago      Up 35 minutes                                k8s--slave.5b0e07ed--e02545c0_-_44ab_-_11e4_-_9dbf_-_080027825feb.etcd--e02545c0_-_44ab_-_11e4_-_9dbf_-_080027825feb--0d0dfb47
7bc212215627        kubernetes/pause:latest           "/pause"               47 minutes ago      Up 47 minutes       0.0.0.0:6380->6379/tcp   k8s--net.74507d56--e02545c0_-_44ab_-_11e4_-_9dbf_-_080027825feb.etcd--e02545c0_-_44ab_-_11e4_-_9dbf_-_080027825feb--02f03970
d244e657597a        dockerfile/redis:latest           "redis-server /etc/r   53 minutes ago      Up 53 minutes                                k8s--master.fbad8aca--redis_-_master_-_2.etcd--05ed6fb6_-_44aa_-_11e4_-_9dbf_-_080027825feb--31e57c43
4b008a5ef6de        kubernetes/pause:latest           "/pause"               About an hour ago   Up About an hour    0.0.0.0:6379->6379/tcp   k8s--net.7b2f7d5e--redis_-_master_-_2.etcd--05ed6fb6_-_44aa_-_11e4_-_9dbf_-_080027825feb--f5fafd75
[vagrant@minion-2 ~]$ docker-enter d244e657597a
nsenter --target 4643 --mount --uts --ipc --net --pid --
[ root@redis-master-2:/ ]$ /usr/local/bin/redis-cli
127.0.0.1:6379> config set stop-writes-on-bgsave-error no
OK
127.0.0.1:6379> exit
[ root@redis-master-2:/ ]$ exit
logout
[vagrant@minion-2 ~]$ exit
logout
Connection to 127.0.0.1 closed.
$ 
```

```
$ open http://192.168.12.11:8000
$ open http://192.168.12.12:8000
```
