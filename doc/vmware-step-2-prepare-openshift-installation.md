# Install OpenShift on VMWare - Step 2 - Prepare for OpenShift installation
The steps below guide you through the preparation of the bastion node and the installation of the OpenShift control plane and workers after you have provisioned the VMs.

## Use screen to multiplex your terminal
The `screen` utility allows you to perform a long-running task in a terminal, which continues even if your connection drops. Once started, you can use `Ctrl-A D` to detach from your screen and `screen -r` to return to the detached screen. If you accidentally started multiple screens, you can use `screen -ls` to list the screen sessions and then attach to one of them using `screen -r <session_id>`. As a best practice, try to have only one screen terminal active to simplify navigation.
```
screen
```





## Prepare the nodes for the OpenShift installation or run the installation
Set environment variables for the root password of the bastion, NFS and load balancer nodes (must be the same) and set the OpenShift administrator (ocadmin) password. If you do not set the environment variables, the script will prompt to specify them.
```
export root_password=<the root password of the servers>
export ocp_admin_password=<The OCP password you want to set for the admin console>
```

### OVA Install

If you are doing a UPI with OVF templates then there are a few extra steps that need to be excuted before installation. First the install binaries should be downloaded to the bastion using the following command:

```
cd ~/cloud-pak-ocp-4
./prepare.sh -i inventory/<inventory-file> --skip-install
```

#### Prepare the VMWare environment for the creation of machines (OVA install)

Before the user can create the machines a template needs to be created within the VMWare environment. From the folder that is house the templates right click and select "Deploy OVF Template"

![Deploy OVF Template](/images/deploy-ovf-template.png)

Enter the details of the OVA file to use for the template. The ova file to use for the template is being served by the bastion node http server from the ocp_install directory. Enter the details of the ova fle to use for the template 

![Select OVF Template](/images/select-ovf-template.png)

Follow the necessary steps to select the name and folder of the template, the vmware compute resource to use. Review the details. Finally select the VMWare storage to use and complte the creation of the template.

After creation the machine created needs to be converted to a template. Right click on the machine created above and select Template -> Convert to Template

![Convert to Template](/images/convert-to-template.png)

#### Create the VMWare machines (OVA install)

The machines can be create manually or if the installer has the correct permissions the creation of the machines can be automated.

With the manual approach the VMWare admin creates the machines with the appropriate compute, memory and storage using as a base the templated created in the previous section

If the creation can be automated the creation of the machines can ve accomplished using the following script:
```
cd ~/cloud-pak-ocp-4
./vm-create.sh -i inventory/<inventory-file> 
```

The use will be prompted for the user id and password of the VMWare account. All machines in the inventory file will be created. 

After setting up the machines run the following to prepare the installation of OpenShift.
```
cd ~/cloud-pak-ocp-4
./prepare.sh -i inventory/<inventory-file> -e vc_user=<vsphere-user> -e vc_password=<vsphere-password> [other parameters...]
```

After the prepare script has finished the VMWare machines will need to be configured withthe ignition files and a couple of extra parameters. This can be accomplished with the following script:
```
cd ~/cloud-pak-ocp-4
./vm-update-vapps.sh -i inventory/<inventory-file> 
```

The user will be prompted for the VMWare user id and password.

### IPI Install if your vSphere user can create VMs
If your vSphere user can create VMs and you are performing and IPI installation or can have the preparation script create the virtual machines, run the script as follows:

```
cd ~/cloud-pak-ocp-4
./prepare.sh -i inventory/<inventory-file> -e vc_user=<vsphere-user> -e vc_password=<vsphere-password> [other parameters...]
```

### Install if the VMs have been pre-created
On the bastion node, you must run the script that will prepare the installation of OpenShift 4.x.
```
cd ~/cloud-pak-ocp-4
./prepare.sh -i inventory/<inventory-file> [other parameters...]
```

### Prepare script failing
If the prepare script fails at some point, you can fix the issue and run the script again. Don't continue to the next step until the Ansible playbook has run successfully.

A successfully completed prepare script output looks something like below. The `unreachable` and `failed` counts should be `0`.
```
PLAY RECAP **************************************************************************************************************************************************************************
192.168.1.100              : ok=15   changed=12   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
localhost                  : ok=79   changed=67   unreachable=0    failed=0    skipped=7    rescued=0    ignored=0

Wednesday 06 May 2020  07:03:41 +0100 (0:00:02.687)       0:04:21.252 *********
===============================================================================
Install common packages ----------------------------------------------------------------------------------------------------------------------------------------------------- 90.25s
.
. <lines suppressed>
.
Generate ignition files for the workers -------------------------------------------------------------------------------------------------------------------------------------- 1.47s
```

## Continue with next step if you chose manual installation
If you specified `run_install=True` in the inventory file, the preparation script will attempt to run the installation to the end, including creation of storage classes and configuring the registry. Should you want to run the installation manually, you can proceed with the next step: installation of OpenShift.

[VMWare - Step 3 - Install OpenShift](/doc/vmware-step-3-install-openshift.md)

## What's happening during the preparation?
If you want to know what is happening during the preparation of the bastion node and OpenShift installation, check here: [Explanation of control plane preparation procedure](/doc/ocp-step-2-prepare-installation-explanation.md)
