# Establish VMWare infrastructure for installation of OpenShift and the Cloud Pak
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
    python3 python3-netaddr python3-passlib python3-pip python3-pyvmomi python3-requests \
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

## Customize the inventory file
You will have to adapt an existing inventory file in the `inventory` directory and choose how the OpenShift and relevant servers are layed out on your infrastructure. The inventory file is used by the `prepare.sh` script which utilizes Ansible to prepare the environment for installation of OpenShift 4.x.

Go to the `inventory` directory and copy one of the exiting `.inv` files. Make sure you review all the properties, but especially:
* Domain name and cluster name, these will be used to define the node names of the cluster
* Proxy configuration (if applicable)
* OpenShift version
* Installation type (PXE Boot or using a VMWare template), see next section
* All IP addresses should match your cluster configuration, including DHCP range

## Create VMWare template
To install the required Red Hat CoreOS (RHCOS) on the cluster nodes, you have two choices:
* PXE Boot (pxe): Create empty nodes. When booted, the operating system will be loaded from the bastion node using TFTP.
* VMWare template (ova): Import the RHCOS file into vSphere and convert to a template; this template will then be used to create the cluster VMs.

## Create the cluster VMs
If you have administrator access to the ESX infrastructure, you can use scripts to automatically create the empty VMs required to stand up an OpenShift cluster. Alternatively, for example if you do not have the required permissions, you can create VMs manually, either empty if you're using PXE boot installation or using a VMWare template.

### Automatic provisioning of the cluster VMs
In the previous step you have customized the inventory file to match your cluster layout and VM properties. You can run the `vm_create.sh` script to create the VMs for the bootstrap, masters and workers. In case you did not set the `vc_user` and `vc_password` environment variables, you will be prompted for the user and password. If the installation type in the inventory file is **pxe**, empty VMs are created; if the installation type is **ova**, VMs will be created based on the specified template.
```
cd ~/cloud-pak-ocp-4
./vm_create.sh -i inventory/<inventory-file> [other parameters...]
```

After creation, the VM folder should look something like this:
![vSphere VMs](/images/vsphere-vm-folder.png)

The MAC-adresses of the newly created VMs are added/updated in the hosts section of the inventory file.

### Manual provisioning of the VMs
If you have NOT created the VMs using the provided script, you will have to manually create VMs on your ESX infrastructure. Either create empty VMs in case of **pxe** installation type, otherwise clone the Red Hat CoreOS template that was imported into vSphere.

Provision the following VMs:
* 1 bootstrap node with 100 GB assigned to the first volume, 4 processing cores and 8 GB of memory
* 3 master nodes, servers with at least 200 GB assigned to the first volume, 8 processing cores and 32 GB of memory
* 3 or more workers, servers with at least 200 GB assigned to the first volume, 16 processing cores and 64 GB of memory
* Optionally, 3 or more workers, used for OCS/Ceph or Portworx. These servers must have 200 GB assiged to the first volume, and one larger (for example 500 GB) volume for the Ceph/Portworx. In case of OCS/Caph, you must also add 1 more 10 GB volume for the monitor data

It recommended to create all virtual servers in a VM folder to keep them together. Also it is best to create a master and worker VM template with the correct specifications so that it is easy to clone them.

After creation, the VM folder should look something like this:
![vSphere VMs](/images/vsphere-vm-folder.png)

#### Update the nodes section(s) in the inventory file
Once provisioned, go to the section in the inventory file that lists the bootstrap, masters and workers and update the host names and MAC addresses in the inventory file. For each node, copy the MAC address as displayed in the network adapter configuration in vSphere, for example:
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
