# Installation based on VMWare templates (OVA)
If the administrator wants to create the VMs based on a template, specify the OVA installation method. The OVA template file must be manually uploaded to the ESX server; this cannot be done by the preparation process. If your user can provision new virtual machines but you do not want to use th IPI, you can have the preparation script create the VMs, update the application settings and start the VMs. If your user cannot control VMs, provide the location of the OVA file and and application settings to the administrator and run through the installation manually.

### Disconnected (air-gapped) installation of OpenShift 4.x
In case you're doing a disconnected installation of OpenShift, update the example inventory file `/inventory/inventory/vmware-airgapped-example.inv` to match your cluster.

## Customize the inventory file
You will have to adapt an existing inventory file in the `inventory` directory and choose how the OpenShift and relevant servers are layed out on your infrastructure. The inventory file is used by the `prepare.sh` script which utilizes Ansible to prepare the environment for installation of OpenShift 4.x.

Go to the `inventory` directory and copy one of the exiting `.inv` files. Make sure you review all the properties, especially:
* Domain name and cluster name, these will be used to define the node names of the cluster
* Proxy configuration (if applicable)
* OpenShift version
* Installation type (OVA) in this case
* Run install: `False`
* DHCP range - Ensure that you have enough free IP addresses for all cluster nodes

You will return to the inventory file after creation of the VMs.

## Prepare the nodes for the OpenShift installation or run the installation

Set environment variables for the root password of the bastion, NFS and load balancer nodes (must be the same) and set the OpenShift administrator (ocadmin) password. If you do not set the environment variables, the script will prompt to specify them.
```
export root_password=<the root password of the servers>
export ocp_admin_password=<The OCP password you want to set for the admin console>
```

### Download VMWare template to bastion node

The following command will download the OVA template to the bastion node so that it can be uploaded to vSphere.

```
cd ~/cloud-pak-ocp-4
./prepare.sh -i inventory/<inventory-file> --skip-install
```

### Create the VMWare template in vSphere

Before the user can create the machines a template needs to be created within the VMWare environment. From the folder that houses the templates or the folder you want to create your OpenShift cluster in, right click and select "Deploy OVF Template"

![Deploy OVF Template](/images/deploy-ovf-template.png)

Enter the details of the OVA file to use for the template. The ova file to use for the template is being served by the bastion node HTTP server (port 8090) from the `ocp_install` directory. Enter the details of the ova file to use for the template:

![Select OVF Template](/images/select-ovf-template.png)

Follow the necessary steps to select the name and folder of the template, the vmware compute resource to use. Finally select the VMWare storage to use and complete the creation of the template.

> You can skip the **Customize template** options where you would normally enter the ignition config data. This will be specified for each of the VMs.

After creation the machine created needs to be converted to a template. Right click on the machine created above and select Template -> Convert to Template

![Convert to Template](/images/convert-to-template.png)

### Create the VMWare machines

With the manual approach the VMWare admin can create the machines with the appropriate compute, memory and storage using the base template created in the previous section.

* 1 bootstrap node with 100 GB assigned to the first volume, 4 processing cores and 8 GB of memory
* 3 master nodes, servers with at least 200 GB assigned to the first volume, 8 processing cores and 32 GB of memory
* 3 or more workers, servers with at least 200 GB assigned to the first volume, 16 processing cores and 64 GB of memory
* Optionally, 3 or more workers, used for OCS/ODF or Portworx. These servers must have 200 GB assiged to the first volume, and one larger (for example 500 GB) volume for the storage

It recommended to create all virtual servers in a VM folder to keep them together. Also it is best to create a master and worker VM template with the correct specifications so that it is easy to clone them.

After creation, your VM folder should look something like this:
![VM Folder](/images/vsphere-vm-folder.png)

### Update the nodes section(s) in the inventory file
Go to the section in the inventory file that lists the bootstrap, masters and workers and update the host names and MAC addresses in the inventory file. For each node, copy the MAC address as displayed in the network adapter configuration in vSphere, for example:
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

### Re-run preparation script
This step creates the remainder of the files needed to complete the installation, such as the application data.
```
cd ~/cloud-pak-ocp-4
./prepare.sh -i inventory/<inventory-file>
```

### Update the VM application data
In the `/ocp_install` directory you will find the `bootstrap-ova.ign.64`, `master.ign.64` and `worker.ign.64` files. You will need to customize every VM you created in the previous steps with the application properties. For each of the VMs:
* Select the VM
* Edit settings
* Go to the VM Options tab
* Open the Advanced section
* Click on `EDIT CONFIGURATION`

Add 3 configuration parameters:
* `guestinfo.ignition.config.data.encoding` --> `base64`
* `guestinfo.ignition.config.data` --> paste the contents of the appropritate `.ign.64` file
* `disk.EnableUUID` --> `TRUE`

## Continue with next step if you chose manual installation
If you specified `run_install=True` in the inventory file, the preparation script will attempt to run the installation to the end, including creation of storage classes and configuring the registry. Should you want to run the installation manually, you can proceed with the next step: installation of OpenShift.

[VMWare - Step 3 - Install OpenShift](/doc/vmware-step-3-install-openshift.md)
