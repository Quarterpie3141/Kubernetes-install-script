#!/bin/bash

set -e

print_info() {
    if [ "$2" -eq 1 ]; then
        printf "\n\n\n"
    fi
    tput setab 6 && tput setaf 0
    printf "$1"
    tput setab 0 && tput setaf 7
    printf "\n"
}

print_success() {
    tput setab 2 && tput setaf 7
    printf "$1"
    tput setab 0 && tput setaf 7
    printf "\n"
}

echo "Starting install script"

#if [[ "$is_control_plane" =~ ^([nN][oO]?|[nN])$ ]]; then
#fi

#read -p "Is this node a control plane(Y/n):" is_control_plane
#is_control_plane=${is_control_plane:-Y}
#if [[ "$is_control_plane" =~ ^([yY][eE][sS]|[yY])$ ]]; then
#    read -p "did you want to set up a control plane endpoint [--control-plane-endpoint]? (y/N):" control_plane_endpoint
#    control_plane_endpoint=${control_plane_endpoint:-N}
#    if [[ "$is_control_plane" =~ ^([nN][oO]?|[nN])$ ]]; then
#       read -p "enter your endpoint address (ip address, domain name)" endpoint_address
#    fi
#fi

#read -p "what version of kubernates are you using(v1.31)" kubernetes_version
#kubernetes_version=${kubernetes_version:-v1.31}
#
#read -p "what container runtime are you using[cri-o | docker | containerd](cri-o)" container_runtime
#echo "kubernetes will use the container runtime interface CRI, by default,if you are using the docker container runtime, please manually configure the cri-dockerd CRI"
#
#container_runtime=${container_runtime:-cri-o}
#
#case "$container_runtime" in
#    cri-o)
#        echo "You selected CRI-O as the container runtime."
#        read -p "What version of CRI-O are you using(v1.30)" cri_o_vers
#        ;;
#    docker)
#        echo "You selected Docker as the container runtime."
#
#        ;;
#    containerd)
#        echo "You selected Containerd as the container runtime."
#
#        ;;
#    *)
#        echo "Invalid input. Please choose between cri-o, docker, or containerd."
#        exit 1  
#        ;;
#esac
#
#
#if [[ "$is_control_plane" =~ ^([yY][eE][sS]|[yY])$ ]]; then
#    read -p "what container container network interface(CNI) are you using [calcio | other](calico):" cni
#    read -p "what is your pod network CIDR[--pod-network-cidr] (192.168.0.0/16)" cni_cidr
#    read -p "did you want to taint this control plane?(y/N)" is_tainted
#fi
#
#read -p "what are your desired node ports?(30000:32767/tcp)" node_ports


printf "Starting the installation process in \n"
for i in {1..5}; do
    printf "$((6-i))"
    for j in {1..3}; do
        printf "."
        sleep 0.5
    done
    printf " "
done

print_info "Updating packages..." 1
sudo apt update
sudo apt upgrade -y
print_success "Done!"

sleep 1

print_info "Disabling swap..." 1
if sudo swapon --show | grep -q '^'; then
    sudo sed -i '/swap/d' /etc/fstab
    sudo cat /etc/fstab
    sleep 1
    sudo swapoff -a
else
    print_success "No active swap space found."
    sleep 1
fi
print_success "Done!"

sleep 1

print_info "Loading kernel modules..." 1
if lsmod | grep -q "^br_netfilter"; then
    print_success "Kernel module br_netfilter is already loaded."
else
    echo "br_netfilter" | sudo tee -a /etc/modules
    sudo cat /etc/modules
    sleep 1
    sudo modprobe br_netfilter
fi
print_success "Done!"

sleep 1

print_info "Enabling IPv4 packet forwarding" 1
if sysctl net.ipv4.ip_forward | grep -q 'net.ipv4.ip_forward = 1'; then
    print_success "IPv4 packet forwarding is already enabled."
else
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    sleep 1
fi
print_success "Done!"

sleep 1

print_info "Installing UFW" 1
sudo apt install -y ufw
print_success "Done!"

sleep 1

print_info "Setting up firewall settings" 1
printf "\n"
print_info "Allowing Kubernetes API server" 0
sudo ufw allow 6443/tcp
printf "\n"
sleep 0.5
print_info "Allowing etcd server client API" 0
sudo ufw allow 2379:2380/tcp
printf "\n"
sleep 0.5
print_info "Allowing Kubelet API" 0
sudo ufw allow 10250/tcp
printf "\n"
sleep 0.5
print_info "Allowing kube-scheduler" 0
sudo ufw allow 10259/tcp
printf "\n"
sleep 0.5
print_info "Allowing kube-controller-manager" 0
sudo ufw allow 10257/tcp
printf "\n"
sleep 0.5
print_info "Allowing kube-proxy" 0
sudo ufw allow 10256/tcp
printf "\n"
sleep 0.5
#if [[ "$cni" =~ ^(calico)$ ]]; then
    print_info "Allowing BIRD" 0
    sudo ufw allow 179/tcp
    printf "\n"
    sleep 0.5
#fi
print_info "Allowing NodePort Services" 0
sudo ufw allow 30000:32767/tcp
print_success "Done!"

sleep 1

print_info "Installing CRI-O" 1
sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates gpg
sudo curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list
sudo apt-get update
sudo apt-get install -y cri-o
print_info "Enabling CRI-O" 0
sleep 1
sudo systemctl start crio.service
print_success "Done!"

sleep 1

print_info "Installing Kubernetes" 1
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt-get install -y kubelet kubeadm kubectl
sleep 1
sudo apt-mark hold kubelet kubeadm kubectl
sleep 1
sudo systemctl enable --now kubelet
print_success "Done!"

print_info "Pulling required config images" 1
kubeadm config images pull 
print_success "Done!"

print_success "Kubeadm is ready to use"