# Install OpenShift on VMWare - Step 2 - Prepare for OpenShift installation
The steps below guide you through the preparation of the bastion node and the installation of the OpenShift control plane and workers after you have provisioned the VMs.

## Use screen to multiplex your terminal
The `screen` utility allows you to perform a long-running task in a terminal, which continues even if your connection drops. Once started, you can use `Ctrl-A D` to detach from your screen and `screen -r` to return to the detached screen. If you accidentally started multiple screens, you can use `screen -ls` to list the screen sessions and then attach to one of them using `screen -r <session_id>`. As a best practice, try to have only one screen terminal active to simplify navigation.
```
screen
```

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

## Prepare the nodes for the OpenShift installation or run the installation
Set environment variables for the root password of the bastion, NFS and load balancer nodes (must be the same) and set the OpenShift administrator (ocadmin) password. If you do not set the environment variables, the script will prompt to specify them.
```
export root_password=<the root password of the servers>
export ocp_admin_password=<The OCP password you want to set for the admin console>
```

### Install if your vSphere user can create VMs
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
