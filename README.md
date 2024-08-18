# Kubernetes Installation Script

This Bash script automates the setup of a Kubernetes node, either as a control plane or a worker node, on Debian-based Linux distributions that use the `apt` package manager. It allows you to customise the necessary settings to bootstrap or join your node to a kubernetes cluster.

## Features

- **Control Plane or Worker Node Setup**: Option to configure the node as a control plane or a worker node.
- **Option to Initalise a High Availability Cluster**: You can point your control plane endpoint to a  virtual ip for highly avalible clusters.
- **Container Runtime Configuration**: Supports `cri-o`, `containerd`, or other container runtimes(you will have to manually install the necessary files for other container runtimes).
- **CNI Setup**: Automatic setup for Calico or manual setup for other CNIs.
- **Firewall Configuration**: Installs and configures UFW with necessary Kubernetes ports.
- **Kubernetes Installation**: Installs specific versions of Kubernetes components (`kubeadm`, `kubelet`, `kubectl`).
- **Automated Cluster Initialization**: Initializes the Kubernetes control plane or joins a worker node to an existing cluster.

## Prerequisites

- Ubuntu or Debian-based Linux distribution.
- root or sudo access.
- network connectivity to download packages and container images.

if you are joining the node to an existing cluster then you will also need:

- Control plane endpoint (including the port) 
- Cluster token 

you can generate a cluster token by running `kubeadm token create`

## Usage

**Disclaimer**: Use this script at your own risk. Ensure you have backups and understand the script and configurations being applied.

1. Install `curl` if your distro doesn't have it:
    ```bash
    $ apt install curl
    ```

2. Download the script:
    ```bash
    $ curl -O https://raw.githubusercontent.com/Quarterpie3141/Kubernetes-install-script/main/kubernetes-install.sh
    ```

3. Make the script executable:
    ```bash
    $ chmod +x ./kubernetes-install.sh
    ```

4. Run the script
    ```bash
    $ ./kubernetes-install.sh
    ```
5. Follow the CLI prompts to configure your cluster(see below)



| **Configuration Option**    | **Description**                                                                 | **Default Value**        |
|-----------------------------|---------------------------------------------------------------------------------|--------------------------|
| **Node Type**               | Choose whether this is a control plane or a worker node.                         | `control-plane`                      |
| **Control Plane Endpoint**  | If setting up a highly available control plane, you can define a control plane endpoint. | N/A                      |
| **Control Plane Address**   | For worker nodes, specify the control plane address and port.                    | N/A                      |
| **Cluster Token**           | The existing cluster token for joining worker nodes.                             | N/A                      |
| **Kubernetes Version**      | Specify the Kubernetes version.*                                                  | `v1.31`                  |
| **Container Runtime**       | Select the container runtime (`cri-o`, `containerd`, or other).                  | `cri-o`                  |
| **Container Runtime Version** | Select the container runtime version.**                                          | `v1.30` (for `cri-o`)    |
| **CNI**                     | Choose the **C**ontainer **N**etwork **I**nterface.                               | `calico`                 |
| **Pod CIDR**                | Specify your pod IP address range.***                                               | `192.168.0.0/16`         |
| **Control Plane Taint**     | Specify if you want to taint your control plane.                                 | `no`                     |
| **Firewall Ports**          | Specify the NodePort range and whether to allow SSH access through UFW.          | `30000:32767/tcp` for NodePorts, `no` for SSH |

<sub>* You can find the most recent version of kuberentes [here](https://kubernetes.io/releases/).</sub><br />
<sub>** You can find the most recent version of CRI-O [here](https://github.com/cri-o/packaging/blob/main/README.md#available-streams).</sub><br />
<sub>*** The default value is the recommended value for Calico, please read the installation instructions of your chosen CNI for more info on the appropriate CIDR.</sub>


## Troubleshooting

If the script fails at any point:

- Ensure you have an active internet connection.
- Check if the necessary ports are open on your firewall(`ufw status`).
- Verify that the correct Kubernetes and container runtime versions are specified.
- Use `kubectl get pods -n kube-system` and `kubectl describe pod -n kube-system <pod-name>` to troubleshoot any failed components.
- If all else fails then follow the [quick start guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) manually


## Contributing

Contributions are welcome! Please fork this repository, create a new branch, and submit a pull request.

---

**Disclaimer**: Use this script at your own risk. Ensure you have backups and understand the script and configurations being applied.


## Script Workflow and Detailed Steps


### 1. Initial Prompts and Configuration
- **Starting Install Script**: The script begins by confirming whether the node is a control plane or a worker node.
- **Control Plane Configuration**:
  - If it's a control plane, you can optionally specify a control plane endpoint for a highly available setup.
  - If it's a worker node, you are prompted to provide the control plane's address and port along with the cluster token.
- **Kubernetes Version**: The script prompts for the Kubernetes version to install.
- **Container Runtime**: You are asked to select a container runtime (`cri-o`, `containerd`, or other) and provide the version if applicable.
- **CNI Configuration**:
  - If the node is a control plane, you are prompted to choose a Container Network Interface (CNI) and specify the pod network CIDR.
- **Pod CIDR Configuration** You can specify the pod network CIDR.
- **Taint Control Plane**: Optionally, you can taint the control plane to prevent workloads from running on it.
- **Firewall Configuration**: The script asks for the desired NodePort range and whether to allow SSH (port 22) through the firewall.

### 2. Validation of Configurations
- **Final Confirmation**: Before proceeding, the script displays all the gathered information and asks for final confirmation to ensure the values are correct.

### 3. Pre-installation Tasks
- **Updating Packages**: The script updates the system’s package list and upgrades installed packages.
- **Disabling Swap**: If any swap space is active, the script disables it, as Kubernetes requires swap to be turned off.
- **Loading Kernel Modules**: Ensures the necessary kernel modules, like `br_netfilter`, are loaded for Kubernetes networking.
- **Enabling IPv4 Packet Forwarding**: Configures the system to enable IPv4 packet forwarding, which is required for Kubernetes networking.

### 4. Firewall Configuration
- **Installing UFW**: The script installs UFW (Uncomplicated Firewall) if it’s not already installed.
- **Configuring UFW**: 
  - It opens the required ports for Kubernetes components such as the API server, etcd, kubelet, kube-proxy, and others.
  - If Calico is selected as the CNI, it also opens ports for BIRD and Typha.
  - Optionally, it allows SSH access through port 22.
- **Enabling UFW**: The script enables the UFW firewall with the configured rules.

### 5. Container Runtime Installation
- **Installing CRI-O**: If CRI-O is selected, the script installs and configures CRI-O as the container runtime.
- **Installing Containerd**: If Containerd is selected, the script installs and configures Containerd.
- **Manual Runtime Installation**: If another runtime is selected, the script advises manual installation and configuration.

### 6. Kubernetes Installation
- **Installing Kubernetes**: The script installs the Kubernetes components (`kubeadm`, `kubelet`, and `kubectl`) using the specified version.
- **Pulling Kubernetes Images**: It pre-pulls necessary Kubernetes images using `kubeadm config images pull` to prepare for cluster initialization.

### 7. Control Plane Initialization (For Control Plane Nodes)
- **Initializing the Control Plane**: 
  - The script initializes the control plane using `kubeadm init`, configuring the control plane endpoint and pod network CIDR.
  - It sets up the kubeconfig file for the user to interact with the cluster using `kubectl`.
  - If the control plane is not tainted, it removes the taint to allow workloads to be scheduled on it.
- **Installing Calico**: If Calico is selected, it applies the Calico manifests to set up the CNI.

### 8. Worker Node Join (For Worker Nodes)
- **Joining the Cluster**: The script generates a certificate hash and uses the provided token to join the worker node to the control plane.

### 9. Finalization
- **Node Status**: The script checks the status of the nodes using `kubectl get nodes` to ensure everything is configured correctly.
