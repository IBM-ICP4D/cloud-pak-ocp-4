# Establish VMWare infrastructure for installation of OpenShift
Before installing OpenShift 4.x you need to provision the (virtual) servers that will host the software. The most common infrastructure is virtual machines on an ESX infrastructure.

In this document we cover the steps for provisioning of demo/POC infrastructure and the expected layout of the cluster.

## Provision bastion node (and potentially an NFS node)
Make sure that the following infrastructure is available or can be created:
* 1 RHEL 8.x, 8 processing cores and 16 GB of memory
* 1 optional RHEL 8.x NFS server, 8 processing cores and 32 GB of memory, if you want to use NFS and don't have an NFS server available already. If you don't want to provision a separate server for NFS storage, you can also use the bastion node for this. In that case make sure you configure the bastion node with 8 processing cores and 32 GB of memory.

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

## Install packages on the bastion node
On the bastion, install the packages which are needed for the preparation, for RHEL-8:
```
yum install -y ansible bind-utils buildah chrony dnsmasq git \
    haproxy httpd-tools jq libvirt net-tools nfs-utils nginx podman \
    python3 python3-netaddr python3-passlib python3-pip python3-policycoreutils python3-pyvmomi python3-requests \
    screen sos syslinux-tftpboot wget yum-utils
```

Additionally, install some additional Python modules:
```
pip3 install passlib
```

> **Note** If your server has more than 1 Python version, Ansible typically chooses the newest version. If `pip3` references a different version of Python than the one used by Ansible, you may have to find the latest version and run the `pip install` against that version.

Example:
```
ls -al /usr/bin/pip*
```

Output:
```
lrwxrwxrwx. 1 root root  23 Sep  5 09:42 /usr/bin/pip-3 -> /etc/alternatives/pip-3
lrwxrwxrwx. 1 root root  22 Sep  5 09:42 /usr/bin/pip3 -> /etc/alternatives/pip3
lrwxrwxrwx. 1 root root   8 Oct 14  2021 /usr/bin/pip-3.6 -> ./pip3.6
-rwxr-xr-x. 1 root root 209 Oct 14  2021 /usr/bin/pip3.6
lrwxrwxrwx. 1 root root   8 Oct 18  2021 /usr/bin/pip-3.8 -> ./pip3.8
-rwxr-xr-x. 1 root root 536 Oct 18  2021 /usr/bin/pip3.8
```

Now install using `pip3.8`:
```
pip3.8 install passlib
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

## Download the OpenShift 4.x pull secret
A pull secret is needed to download the OpenShift assets from the Red Hat registry. You can download your pull secret from here: https://cloud.redhat.com/openshift/install/vsphere/user-provisioned. Click on **Download pull secret**.

Create file `/tmp/ocp_pullsecret.json` on the node from which you run the `prepare.sh` script.

### Disconnected (air-gapped) installation of OpenShift 4.x
If you're doing a disconnected installation of OpenShift, please download the pull secret that was created using the steps in [Create air-gapped registry](/doc/ocp-airgapped-create-registry.md), for example:
```
wget http://registry.uk.ibm.com:8080/ocp4_downloads/ocp4_install/ocp_pullsecret.json -O /tmp/ocp_pullsecret.json
```

Also, download the certificate that of the registry server that was created, for example:
```
wget http://registry.uk.ibm.com:8080/ocp4_downloads/registry/certs/registry.crt -O /tmp/registry.crt
```

> If your registry server is not registered in the DNS, you can add an entry to the `/etc/hosts` file on the bastion node. This file is used for input by the DNS server spun up on the bastion node so the registry server IP address can be resolved from all the cluster node.

## Prepare infrastructure
The next steps depend on which type of installation you are going to do and whether or not you have ESX credentials which will allow you to create VMs. If you have the correct permissions, the easiest is to choose an IPI (Installer Provisioned Infrastructure) installation. With the other two installation types (OVA and PXE Boot) you can choose to manually create the virtual machines.

* IPI: OpenShift will create the VMs as part of the installation. Continue with [IPI installation](/doc/vmware-step-2a-prepare-ipi.md)
* VMWare template (ova): Create nodes based on an OVA template you upload to vSphere. Continue with [OVA installation](/doc/vmware-step-2b-prepare-ova.md)
* PXE Boot (pxe): Create empty nodes. When booted, the operating system will be loaded from the bastion node using TFTP. Continue with [PXE Boot installation](/doc/vmware-step-2c-prepare-pxe.md)
