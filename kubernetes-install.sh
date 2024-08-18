#!/bin/bash

set -e

print_info() {
    if [ "$2" -eq 1 ]; then
        printf "\n\n\n"
    fi
    tput smul
    tput setab 0 && tput setaf 6
    printf "$1"
    tput setab 0 && tput setaf 7
    tput rmul
    printf "\n"
}

print_success() {
    tput setab 0 && tput setaf 2
    printf "$1"
    tput setab 0 && tput setaf 7
    printf "\n"
}

print_warn() {
    tput setab 0 && tput setaf 3
    printf "$1"
    tput setab 0 && tput setaf 7
    printf "\n"
}


tput smul && tput setaf 2
echo "Starting install script"
tput smul && tput setaf 7
read -p "Is this node a control plane(Y/n): " is_control_plane
tput rmul && tput setaf 7
printf "\n"
is_control_plane=${is_control_plane:-Y}

if [[ "$is_control_plane" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    tput smul
    read -p "Did you want to set up a control plane endpoint [--control-plane-endpoint]? (y/N): " control_plane_endpoint
    tput rmul
    printf "\n"
    control_plane_endpoint=${control_plane_endpoint:-N}
    if [[ "$control_plane_endpoint" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        tput smul
        read -p "Enter your endpoint address: " endpoint_address
        tput rmul
        printf "\n"
    fi
else
    while [ -z "$control_plane_address" ]; do
        tput smul7
        read -p "What is your control plane address and port [<ip>:<port> | <fqdn>:<port>]? " control_plane_address
        tput rmul
        printf "\n"
        if [ -z "$control_plane_address" ]; then
            tput smul
            echo "Control plane address cannot be empty. Please enter a IP or FQDN."
            tput rmul
            printf "\n"
        fi
    done

    while [ -z "$cluster_token" ]; do
        tput smul    
        read -p "What is your existing cluster token [kubeadm token create]? " cluster_token
        tput rmul
        printf "\n"
        if [ -z "$cluster_token" ]; then
            print_warn "Cluster token cannot be empty. Please enter a token."
        fi
    done
fi
tput smul
read -p "What version of Kubernetes are you using(v1.31): " kubernetes_version
kubernetes_version=${kubernetes_version:-v1.31}
tput rmul
printf "\n"
tput smul
read -p "What container runtime are you using [cri-o | containerd | other](cri-o): " container_runtime
tput rmul
printf "\n"
container_runtime=${container_runtime:-cri-o}

case "$container_runtime" in
    cri-o)
        print_warn "You selected CRI-O as the container runtime."
        tput smul
        read -p "What version of CRI-O are you using (v1.30): " cri_o_vers
        tput rmul
        printf "\n"
        cri_o_vers=${cri_o_vers:-v1.30}
        ;;
    containerd)
        print_warn "You selected Containerd as the container runtime."
        printf "\n"
        ;;
    other)
        print_warn "You will have to manually install your chosen container runtime."
        print_warn  "If you are using Docker, please manually configure the cri-dockerd CRI."
        printf "\n"
        ;;
    *)
        print_warn "Invalid input. Please choose between cri-o, other, or containerd."
        exit 1  
        ;;
esac

if [[ "$is_control_plane" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    tput smul
    read -p "What container network interface (CNI) are you using [calico | other](calico): " cni
    tput rmul
    printf "\n"
    cni=${cni:-calico}
    if [[ "$cni" =~ ^(other)$ ]]; then
        print_warn "You will have to manually install your desired CNI after this script finishes."
    else
        tput smul
        read -p "What version of Calico are you using? (v3.28.1): " calico_vers
        tput rmul
        printf "\n"
        calico_vers=${calico_vers:-v3.28.1}
        tput smul
        read -p "What is your pod network CIDR [--pod-network-cidr] (192.168.0.0/16): " cni_cidr
        tput rmul
        printf "\n"
        cni_cidr=${cni_cidr:-192.168.0.0/16}
    fi
    tput smul
    read -p "Did you want to taint this control plane? (y/N): " is_tainted
    tput rmul
    printf "\n"
    is_tainted=${is_tainted:-N}
fi
tput smul
read -p "What are your desired node ports? (30000:32767/tcp): " node_ports
tput rmul
printf "\n"
node_ports=${node_ports:-30000:32767/tcp}

print_warn "This script will install and enable UFW, which may block SSH connections"
print_warn "Did you want to let port 22 (ssh) through the firewall?"
tput smul
read -p "(N/y): " allow_22
allow_22=${allow_22:-n}
tput rmul


print_all_values() {
    echo "Are the following values correct?:"
    echo "Is control plane: $is_control_plane"
    if [[ "$is_control_plane" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Control plane endpoint: $control_plane_endpoint"
        if [[ "$control_plane_endpoint" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "Endpoint address: $endpoint_address"
        fi
        echo "CNI: $cni"
        if [[ "$cni" != "calico" ]]; then
            echo "CNI CIDR: $cni_cidr"
        fi
        echo "Is tainted: $is_tainted"
    fi
    echo "Kubernetes version: $kubernetes_version"
    echo "Container runtime: $container_runtime"
    if [[ "$container_runtime" == "cri-o" ]]; then
        echo "CRI-O version: $cri_o_vers"
    fi
    echo "Node ports: $node_ports"
    echo "Allow SSH: $allow_22"
}
printf "\n \n \n"
print_all_values

read -p "(Y/n): Are the above values correct? " final_check

if [[ "$final_check" =~ ^([nN][oO]|[nN])$ ]]; then
    exit 1
fi

printf "Starting the installation process in\n"
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

print_info "Enabling IPv4 packet forwarding..." 1
if sysctl net.ipv4.ip_forward | grep -q 'net.ipv4.ip_forward = 1'; then
    print_success "IPv4 packet forwarding is already enabled."
else
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    sleep 1
fi
print_success "Done!"

sleep 1

print_info "Installing UFW..." 1
sudo apt install -y ufw
print_success "Done!"

sleep 1

print_info "Setting up firewall settings..." 1
printf "\n"
print_info "Allowing Kubernetes API server..." 0
sudo ufw allow 6443/tcp
printf "\n"
sleep 0.5
print_info "Allowing etcd server client API..." 0
sudo ufw allow 2379:2380/tcp
printf "\n"
sleep 0.5
print_info "Allowing Kubelet API..." 0
sudo ufw allow 10250/tcp
printf "\n"
sleep 0.5
print_info "Allowing kube-scheduler..." 0
sudo ufw allow 10259/tcp
printf "\n"
sleep 0.5
print_info "Allowing kube-controller-manager..." 0
sudo ufw allow 10257/tcp
printf "\n"
sleep 0.5
print_info "Allowing kube-proxy..." 0
sudo ufw allow 10256/tcp
printf "\n"
sleep 0.5
if [[ "$cni" =~ ^(calico)$ ]]; then
    print_info "Allowing BIRD..." 0
    sudo ufw allow 179/tcp
    printf "\n"
    sleep 0.5
    print_info "Allowing Typha..." 0
    sudo ufw allow 5473/tcp
    printf "\n"
    sleep 0.5
fi
print_info "Allowing NodePort Services..." 0
sudo ufw allow "$node_ports"

if [[ "$allow_22" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    print_info "Allowing SSH..." 0
    sudo ufw allow 22/tcp
    printf "\n"
    sleep 0.5
fi
print_success "Done!"
print_info "Enabling Firewall..." 1
yes | sudo ufw enable
print_success "Done!"

sleep 1

if [[ $container_runtime =~ ^(cri-o)$ ]]; then
    print_info "Installing CRI-O..." 1
    sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates gpg
    sudo curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/$cri_o_vers/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/$cri_o_vers/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list
    sudo apt-get update
    sudo apt-get install -y cri-o
    print_info "Enabling CRI-O..." 0
    sleep 1
    sudo systemctl enable crio.service
    sudo systemctl start crio.service
    print_success "Done!"

elif [[ $container_runtime =~ ^(containerd)$ ]]; then
    sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates gpg
    sudo apt-get update
    sudo apt-get install -y containerd
    print_info "Enabling containerd..." 0
    sleep 1
    sudo systemctl enable containerd.service
    sudo systemctl start containerd.service
    print_success "Done!"
fi
if [[ "$container_runtime" != "other" ]]; then
    sleep 1
    print_info "Installing Kubernetes..." 1
    sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates gpg
    sudo apt update
    curl -fsSL https://pkgs.k8s.io/core:/stable:/$kubernetes_version/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$kubernetes_version/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt update
    sudo apt-get install -y kubelet kubeadm kubectl
    sleep 1
    sudo apt-mark hold kubelet kubeadm kubectl
    sleep 1
    sudo systemctl enable --now kubelet
    print_success "Done!"

    print_info "Pulling required config images, this may take a few minutes..." 1
    kubeadm config images pull 
    print_success "Done!"

    print_success "Kubeadm is ready to use"

    if [[ "$is_control_plane" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Initializing cluster..."
        kubeadm init --control-plane-endpoint "$endpoint_address" --pod-network-cidr "$cni_cidr"
        echo "Cluster initialization complete."

        echo "Running post-init script..."
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        echo "Post-init script complete."

        if [[ "$is_tainted" =~ ^([Nn][Oo]|[nN])$ ]]; then
            kubectl taint nodes --all node-role.kubernetes.io/control-plane-
        fi

        if [[ "$cni" == "calico" ]]; then
            kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$calico_vers/manifests/tigera-operator.yaml
            kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$calico_vers/manifests/custom-resources.yaml
        fi
    else
        ca_cert=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
        kubeadm join "$control_plane_address" --token "$cluster_token" --discovery-token-ca-cert-hash sha256:"$ca_cert"
    fi

    kubectl get nodes -o wide

    echo "Your Kubernetes node has been initialized with no errors."
else
    echo "Your node is ready to have kubernetes installed"
fi