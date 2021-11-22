# Installation based on PXE Boot (PXE)
If your vSphere user cannot provision new virtual machines or if you want to determine the names of your nodes or use static IP addresses, you can use the PXE boot installation option.

### Create empty VMWare machines

With the manual approach the VMWare admin can create **empty** machines with the appropriate compute, memory and storage using the base template created in the previous section.

* 1 bootstrap node with 100 GB assigned to the first volume, 4 processing cores and 8 GB of memory
* 3 master nodes, servers with at least 200 GB assigned to the first volume, 8 processing cores and 32 GB of memory
* 3 or more workers, servers with at least 200 GB assigned to the first volume, 16 processing cores and 64 GB of memory
* Optionally, 3 or more workers, used for OCS/ODF or Portworx. These servers must have 200 GB assiged to the first volume, and one larger (for example 500 GB) volume for the storage

It recommended to create all virtual servers in a VM folder to keep them together. Also it is best to create a master and worker VM template with the correct specifications so that it is easy to clone them.

After creation, your VM folder should look something like this:
![VM Folder](/images/vsphere-vm-folder.png)

### Disconnected (air-gapped) installation of OpenShift 4.x
In case you're doing a disconnected installation of OpenShift, update the example inventory file `/inventory/inventory/vmware-airgapped-example.inv` to match your cluster.

## Customize the inventory file
You will have to adapt an existing inventory file in the `inventory` directory and choose how the OpenShift and relevant servers are layed out on your infrastructure. The inventory file is used by the `prepare.sh` script which utilizes Ansible to prepare the environment for installation of OpenShift 4.x.

Go to the `inventory` directory and copy one of the exiting `.inv` files. Make sure you review all the properties, especially:
* Domain name and cluster name, these will be used to define the node names of the cluster
* Proxy configuration (if applicable)
* OpenShift version
* Installation type (PXE) in this case
* DHCP range - Ensure that you have enough free IP addresses for all cluster nodes.
* Nodes section - Specify the IP addresses and names of the bootstrap, masters and workers. If your virtual machines have been pre-created by a vSphere administrator, also specify the MAC address associated with each VM so that the DHCP server will assign the correct IP address.

For each node, copy the MAC address as displayed in the network adapter configuration in vSphere, for example:
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

## Prepare the nodes for the OpenShift installation or run the installation

Set environment variables for the root password of the bastion, NFS and load balancer nodes (must be the same) and set the OpenShift administrator (ocadmin) password. If you do not set the environment variables, the script will prompt to specify them.
```
export root_password=<the root password of the servers>
export ocp_admin_password=<The OCP password you want to set for the admin console>
```

### Run the preparation script
On the bastion node, you must run the script that will prepare the installation of OpenShift 4.x.
```
cd ~/cloud-pak-ocp-4
./prepare.sh -i inventory/<inventory-file> [other parameters...]
```

## Continue with next step
If you specified `run_install=True` in the inventory file, the preparation script will attempt to run the installation to the end, including creation of storage classes and configuring the registry. Should you want to run the installation manually, you can proceed with the next step: installation of OpenShift.

[VMWare - Step 3 - Install OpenShift](/doc/vmware-step-3-install-openshift.md)
