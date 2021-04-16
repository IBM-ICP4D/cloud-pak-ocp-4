# Establish VMWare infrastructure for installation of OpenShift
Before installing OpenShift 4.x you need to provision the (virtual) servers that will host the software. The most common infrastructure is virtual machines on an ESX infrastructure.

In this document we cover the steps for provisioning of demo/POC infrastructure and the expected layout of the cluster.

## Provision bastion node (and potentially an NFS node)
Make sure that the following infrastructure is available or can be created:
* 1 RHEL 8.1+ or 7.7+ Bastion node, 8 processing cores and 16 GB of memory
* 1 optional RHEL 8.1+ or 7.7+ NFS server, 8 processing cores and 32 GB of memory, if you want to use NFS and don't have an NFS server available already. If you don't want to provision a separate server for NFS storage, you can also use the bastion node for this. In that case make sure you configure the bastion node with 8 processing cores and 32 GB of memory.

## Log on to the Bastion node
Log on to the bastion node as `root`.

## Disable the firewall on the bastion node
The bastion node will host the OpenShift installation files. On a typical freshly installed RHEL server, the `firewalld` service is activated by default and this will cause problems, so you need to disable it.
```
systemctl stop firewalld;systemctl disable firewalld
```

## Enable required repositories on the bastion node (and NFS if in use)
You must install certain packages on the bastion node (and optionally NFS) for the preparation script to function. These will come from Red Hat Enterprise Linux and EPEL repositories. Make sure the following repositories are available from Red Hat or the satellite server in use for the infrastructure:
* rhel-server-rpms - Red Hat Enterprise Linux Server (RPMs)

For EPEL, you need the following repository:
* epel/x86_64 - Extra Packages for Enterprise Linux - x86_64

If you don't have this repository configured yet, you can do as as follows for RHEL-8:
```
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
```

For RHEL-7, do the following:
```
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
```

## Install packages on the bastion node
On the bastion, install the packages which are needed for the preparation, for RHEL-8:
```
yum install -y ansible bind-utils buildah chrony dnsmasq git \
    haproxy httpd-tools jq libvirt net-tools nfs-utils nginx podman \
    python3 python3-netaddr python3-passlib python3-pip python3-policycoreutils python3-pyvmomi python3-requests \
    screen sos syslinux-tftpboot wget yum-utils
```

For RHEL-7, do the following:
```
yum install -y ansible bind-utils buildah chrony dnsmasq git \
    haproxy httpd-tools jq libvirt net-tools nfs-utils nginx podman \
    policycoreutils-python python3 python-netaddr python-passlib python-pip python-pyvmomi python-requests \
    screen sos syslinux-tftpboot wget yum-utils
```

If you have a separate storage server, please install the following packages on that VM (works for both RHEL-8 and RHEL-7):
```
yum install -y bind-utils chrony net-tools nfs-utils wget yum-utils
```

## Clone this repo
If you have access to the internet from the bastion, you can also clone this repository using the following procedure.
```
cd /root
git clone https://github.com/IBM-ICP4D/cloud-pak-ocp-4.git
```

### Alternative: upload the repository zip
Export this repository to a zip file and upload it to the Bastion node. Unzip the file in a directory of your preference, typically `/root`.

## Prepare registry server (in case of disconnected installation)
If you're doing a disconnected (air-gapped) installation of OpenShift, please ensure you set up a registry server. You can follow the instructions in the Red Hat OpenShift documentation or the steps documented here: [Create air-gapped registry](/doc/ocp-airgapped-create-registry.md)

## Create the cluster VMs (if you don't have the vSphere credentials)
If you have administrator access to the ESX infrastructure, you can select the IPI install or specify that the VMs are automatically created during the preparation steps. If you don't have administrator access, you can have the vSphere administrator create VMs manually, either empty if you're using PXE boot installation or using a VMWare template (OVA).

Provision the following VMs:
* 1 bootstrap node with 100 GB assigned to the first volume, 4 processing cores and 8 GB of memory
* 3 master nodes, servers with at least 200 GB assigned to the first volume, 8 processing cores and 32 GB of memory
* 3 or more workers, servers with at least 200 GB assigned to the first volume, 16 processing cores and 64 GB of memory
* Optionally, 3 or more workers, used for OCS/Ceph or Portworx. These servers must have 200 GB assiged to the first volume, and one larger (for example 500 GB) volume for the Ceph/Portworx. In case of OCS/Caph, you must also add 1 more 10 GB volume for the monitor data

It recommended to create all virtual servers in a VM folder to keep them together. Also it is best to create a master and worker VM template with the correct specifications so that it is easy to clone them.

After creation, the VM folder should look something like this:
![vSphere VMs](/images/vsphere-vm-folder.png)

## Customize the inventory file
You will have to adapt an existing inventory file in the `inventory` directory and choose how the OpenShift and relevant servers are layed out on your infrastructure. The inventory file is used by the `prepare.sh` script which utilizes Ansible to prepare the environment for installation of OpenShift 4.x.

Go to the `inventory` directory and copy one of the exiting `.inv` files. Make sure you review all the properties, but especially:
* Domain name and cluster name, these will be used to define the node names of the cluster
* Proxy configuration (if applicable)
* OpenShift version
* Installation type (IPI, PXE Boot or using a VMWare template), see next section

## Choose installation type
To install the required Red Hat CoreOS (RHCOS) on the cluster nodes, you have two main choices: you can let OpenShift provision the infrastructure (installer-provisioned infrastructure) or provision the infrastructure yourself (user-provisoned infrastructure). With UPI you can then choose between PXE boot or VMWare template installation.
* IPI: OpenShift will create the VMs as part of the installation.
* PXE Boot (pxe): Create empty nodes. When booted, the operating system will be loaded from the bastion node using TFTP.
* VMWare template (ova): Create nodes based on an OVA template that was uploaded to vSphere.

Below you will find the infrastructure preparation steps required for each of the installation methods, along with the most-important inventory settings.

### IPI installation
This is the most straightforward installation method if your vSphere user can provision new virtual machines. The OpenShift installation process uploads a VM template and clones this into the bootstrap, masters and workers and provisions the clusters. Ensure that you have reviewed and adjusted the following additional settings in the inventory file:
* DHCP range - Ensure that you have enough free IP addresses for all cluster nodes.
* VIP addresses - Virtual IP adress for the API (masters) and the ingress (workers).
* VM settings - vSphere server, data center, data store, resource pool, master and worker specs, number of masters and workers.
* Nodes section - The sections for bootstrap, masters and workers will be ignored because OpenShift will determine the name of the nodes. However, do not remove the sections, they must exist.

When running the prepare script in the next step, you must specify the vc_user and vc_password parameters. Make sure that you have them handy.

### PXE boot installation
This is the preferred option if your vSphere user cannot provision new virtual machines or if you want to determine the names of your nodes or use static IP addresses. You can also use this option if your user _can_ create virtual machines but you want to have cnotrol over the cluster node names and IP addresses. Ensure you have reviewed and adjusted the following settings in the inventory file:
* DHCP range - Ensure that you have enough free IP addresses for all cluster nodes.
* VM settings - If you can create VMs, specify the vSphere server, data center, data store, resource pool, master and worker specs.
* Nodes section - Specify the IP addresses and names of the bootstrap, masters and workers. If your virtual machines have been pre-created by a vSphere administrator, also specify the MAC address associated with each VM so that the DHCP server will assign the correct IP address.

### OVA installation
If you don't want to use PXE boot or the administrator wants to create the VMs based on a template, specify the OVA installation method. The OVA template file must be manually uploaded to the ESX server; this cannot be done by the preparation process. If your user can provision new virtual machines, you can have the preparation script create the VMs, update the application settings and start the VMs. If your user cannot control VMs, provide the OVA file and application settings to the administrator and run through the installation manually. Ensure you have reviewed and adjusted the following settings in the inventory file:
* DHCP range - Ensure that you have enough free IP addresses for all cluster nodes.
* VM settings - If you can create VMs, specify the vSphere server, data center, data store, resource pool, master and worker specs.
* VM template file - Full location of the template that was created from the OVA file.
* Nodes section - Specify the IP addresses and names of the bootstrap, masters and workers. If your virtual machines have been pre-created by a vSphere administrator, also specify the MAC address associated with each VM so that the DHCP server will assign the correct IP address.

### Update the nodes section(s) in the inventory file (PXE boot)
If your ESX administrator has provisioned the infrastructure and you use install through PXE boot, go to the section in the inventory file that lists the bootstrap, masters and workers and update the host names and MAC addresses in the inventory file. For each node, copy the MAC address as displayed in the network adapter configuration in vSphere, for example:
![vSphere MAC address](/images/vsphere-mac-address.png)

After making the changes to the inventory file, the bottom section of the inventory file should look something like this:
```
[bootstrap]
10.99.92.52 host="bootstrap" mac="00:50:56:ab:81:bb"

[masters]
10.99.92.53 host="master-1" mac="00:50:56:ab:55:e0"
10.99.92.54 host="master-2" mac="00:50:56:ab:9b:48"
10.99.92.55 host="master-3" mac="00:50:56:ab:10:ab"

[workers]
10.99.92.56 host="worker-1" mac="00:50:56:ab:3f:8b"
10.99.92.57 host="worker-2" mac="00:50:56:ab:ec:78"
10.99.92.58 host="worker-3" mac="00:50:56:ab:b2:6d"
```

### Disconnected (air-gapped) installation of OpenShift 4.x
In case you're doing a disconnected installation of OpenShift, update the example inventory file `/inventory/inventory/vmware-airgapped-example.inv` to match your cluster.

## Continue with next step
Once you've provisioned the VMs, you can proceed with the preparation of the bastion node for the OpenShift installation:

[VMWare - Step 2 - Prepare for OpenShift installation](/doc/vmware-step-2-prepare-openshift-installation.md)
