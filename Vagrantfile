# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

NUM_MINIONS = 2

BASE_IP_ADDR    = ENV['BASE_IP_ADDR'] || "192.168.12"
ETCD_DISCVERY   = "#{BASE_IP_ADDR}.101"
MASTER_IP_ADDR  = "#{BASE_IP_ADDR}.10"
MINION_IP_ADDRS = NUM_MINIONS.times.collect { |i| BASE_IP_ADDR + ".#{i+11}" }

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "yungsang/fedora-atomic"

  config.vm.box_version = ">= 1.0.0"

  config.vm.define "discovery" do |discovery|
    discovery.vm.hostname = "discovery"

    discovery.vm.network :private_network, ip: ETCD_DISCVERY

    discovery.vm.provision :file, source: "./discovery.sh", destination: "/tmp/user-data.sh"

    discovery.vm.provision :shell do |sh|
      sh.privileged = true
      sh.inline = <<-EOT
        sed -e "s/%ADDR%/#{ETCD_DISCVERY}/g" -i /tmp/user-data.sh

        chmod +x /tmp/user-data.sh
        /tmp/user-data.sh
      EOT
    end
  end

  config.vm.define "master" do |master|
    master.vm.hostname = "master"

    master.vm.network :forwarded_port, guest: 4001, host: 4001

    master.vm.network :private_network, ip: MASTER_IP_ADDR

    # Install flannel
    master.vm.provision :docker do |d|
      d.run "yungsang/flannel",
        args: "--rm -v /opt/bin:/target --privileged",
        auto_assign_name: false, daemonize: false
    end

    master.vm.provision :file, source: "./master.sh", destination: "/tmp/user-data.sh"

    master.vm.provision :shell do |sh|
      sh.privileged = true
      sh.inline = <<-EOT
        sed -e "s/%ADDR%/#{MASTER_IP_ADDR}/g" -i /tmp/user-data.sh
        sed -e "s/%ETCD_DISCVERY%/#{ETCD_DISCVERY}/g" -i /tmp/user-data.sh
        sed -e "s/%MINION_IP_ADDRS%/#{MINION_IP_ADDRS.join(',')}/g" -i /tmp/user-data.sh

        chmod +x /tmp/user-data.sh
        /tmp/user-data.sh
      EOT
    end
  end

  NUM_MINIONS.times do |i|
    config.vm.define "minion-#{i+1}" do |minion|
      minion.vm.hostname = "minion-#{i+1}"

      minion.vm.network :private_network, ip: MINION_IP_ADDRS[i]

      # Install flannel
      minion.vm.provision :docker do |d|
        d.run "yungsang/flannel",
          args: "--rm -v /opt/bin:/target --privileged",
          auto_assign_name: false, daemonize: false
      end

      minion.vm.provision :file, source: "./minion.sh", destination: "/tmp/user-data.sh"

      minion.vm.provision :shell do |sh|
        sh.privileged = true
        sh.inline = <<-EOT
          sed -e "s/%ADDR%/#{MINION_IP_ADDRS[i]}/g" -i /tmp/user-data.sh
          sed -e "s/%ETCD_DISCVERY%/#{ETCD_DISCVERY}/g" -i /tmp/user-data.sh

          chmod +x /tmp/user-data.sh
          /tmp/user-data.sh
        EOT
      end
    end
  end
end
