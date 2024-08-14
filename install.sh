#!/bin/bash

set -e
print_info() {
    if [$2 -eq 1]; then
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

#progress_indicator & indicator_pid=$!

#kill $indicator_pid

#wait $indicator_pid 2>/dev/null

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


print_info "Disabling swap..." 1

if sudo swapon --show | grep -q '^'; then
    sudo sed -i '/swap/d' /etc/fstab
    sudo cat /etc/fstab
    sudo swapoff -a
else
    print_success "No active swap space found."
fi
print_success "Done!"

print_info "Loading kernel modules..." 1
if lsmod | grep -q "^br_netfilter"; then
    print_success "Kernel module br_netfilter is already loaded."
else
    echo "br_netfilter" | sudo tee -a /etc/modules
    sudo cat /etc/modules
    sudo modprobe br_netfilter
fi
print_success "Done!"

print_info "Enabling ipv4 packet forwarding" 1

if sysctl net.ipv4.ip_forward | grep -q 'net.ipv4.ip_forward = 1'; then
    print_success "IPv4 packet forwarding is already enabled."
else
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
fi
print_success "Done!"

print_info "Installing ufw" 1
sudo apt install -y ufw
print_success "Done!"

print_info "Setting up firewall settings" 1
print_info "Allowing Kubernetes API server" 0
sudo ufw allow 6443/tcp
print_info "Allowing etcd server client API" 0
sudo ufw allow 2379:2380/tcp
print_info "Allowing Kubelet API" 0
sudo ufw allow 10250/tcp
print_info "Allowing kube-scheduler" 0
sudo ufw allow 10259/tcp
print_info "Allowing kube-controller-manager" 0
sudo ufw allow 10257/tcp
print_info "Allowing kube-proxy" 0
sudo ufw allow 10256/tcp
print_info "Allowing NodePort Services" 0
sudo ufw allow 30000:32767/tcp
print_info "Allowing NodePort Services" 0
print_success "Done!"

print_info "Installing CRI-O" 1
sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates gpg
sudo curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list
sudo apt-get update
sudo apt-get install -y cri-o
print_info "Enabling CRI-O" 0
sudo systemctl start crio.service
print_success "Done!"

print_info "Installing Kubernetes" 1
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

print_success "Done!"

print_success "Kubeadm is ready to use"
