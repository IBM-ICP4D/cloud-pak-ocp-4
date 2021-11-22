# Installation using Installer Provisioned Infrastructure (IPI)
This is the most straightforward installation method if your vSphere user can provision new virtual machines. The OpenShift installation process uploads a VM template and clones this into the bootstrap, masters and workers and provisions the clusters.

> When running the prepare script in the next step, you must specify the vc_user and vc_password parameters. Make sure that you have them handy.

### Disconnected (air-gapped) installation of OpenShift 4.x
In case you're doing a disconnected installation of OpenShift, update the example inventory file `/inventory/inventory/vmware-airgapped-example.inv` to match your cluster.

## Customize the inventory file
You will have to adapt an existing inventory file in the `inventory` directory and choose how the OpenShift and relevant servers are layed out on your infrastructure. The inventory file is used by the `prepare.sh` script which utilizes Ansible to prepare the environment for installation of OpenShift 4.x.

Go to the `inventory` directory and copy one of the exiting `.inv` files. Make sure you review all the properties, especially:
* Domain name and cluster name, these will be used to define the node names of the cluster
* Proxy configuration (if applicable)
* OpenShift version
* Installation type (IPI) in this case
* DHCP range - Ensure that you have enough free IP addresses for all cluster nodes.
* Ingress and API virtual IP addresses
* Number of masters and workers and VM properties
* VMWare environment settings
* Nodes section - The sections for bootstrap, masters and workers will be ignored because OpenShift will determine the name of the nodes. However, do not remove the sections, they must exist.

### IPI Install
Run the script as follows. It will prepare the bastion node and continue with the IPI install.
```
cd ~/cloud-pak-ocp-4
./prepare.sh -i inventory/<inventory-file> -e vc_user=<vsphere-user> -e vc_password=<vsphere-password> [other parameters...]
```

After installation is finished, you can start using OpenShift.

## Keep the cluster running for 24h
> **IMPORTANT:** After completing the OpenShift 4.x installation, ensure that you keep the cluster running for at least 24 hours. This is required to renew the temporary control plane certificates. If you shut down the cluster nodes before the control plane certificates are renewed and they expire while the cluster is down, you will not be able to access OpenShift.

## Access OpenShift (optional)
You can now access OpenShift by editing your `/etc/hosts` file. See [Access OpenShift](/doc/access-openshift.md) for more details.