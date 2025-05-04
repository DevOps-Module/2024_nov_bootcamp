#!/bin/bash

# This script has been tested on Ubuntu 22.04.
# https://hbayraktar.medium.com/how-to-install-kubernetes-cluster-on-ubuntu-22-04-step-by-step-guide-7dbf7e8f5f99
# https://kubernetes.io/docs/reference/networking/ports-and-protocols/
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart
#sudo kubeadm init --control-plane-endpoint="PrivateIP:6443" --upload-certs --apiserver-advertise-address=PrivateIP --pod-network-cidr=192.168.0.0/16


echo "[TASK 0] Disable SWAP"
swapoff -a; sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab


echo "[TASK 1] Add Kernel Parameters"
# Load the required kernel modules
tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Configure the critical kernel parameters for Kubernetes using the following:
tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload the changes
sysctl --system


echo "[TASK 2] Install a container runtime"
apt update -qq >/dev/null 2>&1
apt install -qq -y curl gnupg2 software-properties-common apt-transport-https ca-certificates >/dev/null 2>&1

# Enable Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg >/dev/null 2>&1
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >/dev/null 2>&1

# Update the package list and install containerd:
apt update -qq >/dev/null 2>&1
apt install -qq -y containerd.io >/dev/null 2>&1

# Configure containerd to start using systemd as cgroup & restart containerd:
containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd >/dev/null 2>&1


echo "[TASK 3] Add apt repo for kubernetes"
# https://kubernetes.io/blog/2023/08/31/legacy-package-repository-deprecation/
apt update -qq >/dev/null 2>&1
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
# In releases older than Debian 12 and Ubuntu 22.04, the folder /etc/apt/keyrings does not exist by default, and it should be created before the curl command.
# mkdir /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null 2>&1


echo "[TASK 4] Install Kubernetes components (kubeadm, kubelet and kubectl)"
apt update -qq >/dev/null 2>&1
apt install -qq -y kubelet kubeadm kubectl >/dev/null 2>&1
apt-mark hold kubelet kubeadm kubectl
