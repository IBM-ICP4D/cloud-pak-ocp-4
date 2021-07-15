# Install Red Hat OpenShift 4.x on VMWare or Bare Metal

The instructions in this repository are designed to lay out the Red Hat OpenShift Container Platform (OCP) 4.x on various infrastructures for custom demos and POCs of the IBM Cloud Paks. It is intended for those who want to fasttrack installing OpenShift with some tried and tested automation. It saved several IBM-ers numerous hours everytime they need to set up a cluster to do Cloud Pak demos.

**IMPORTANT NOTE: It is not intended for this repository to configure and deploy OpenShift or a Cloud Pak for production use.**

This repository covers the main steps in the provisioning process. 

## Cluster topology and installation process
The deployment instructions have been written with the following topology in mind:
![OpenShift 4.x cluster topology](/images/cluster-topology.png)

In the topology, the **Bastion** node plays a key role. At installation time, it serves as the node from which the OpenShift installation process is run and it serves the Red Hat CoreOS boot and ISO images in case of a PXE install. More permanently, it acts as a Load Balancer, DNS, NTP and NFS server (for the image registry and applications).

Red Hat documents two main options for laying out the OpenShift Container Platform (OCP): IPI (Installer Provided Infrastructure) and UPI (User Provided Infrastructure). This repository and guide provides assets for both.

### OpenShift installation process on VMWare
When deploying on VMWare infrastructure, you can either create the VMs that make up the OpenShift cluster nodes manually and then proceed with the OpenShift installation, or you can automatically create the VMs through the provided Ansible scripts or via the IPI installation method. For automatic provisioning and IPI installation, you must have access to the ESX user and password.

![VMWare - OCP installation process](/images/ocp-installation-process-vmware.png)

## Step 1 - Provision Bastion node and (optionally) cluster nodes
Before you can install OpenShift, you need a bastion node from which the installation will be run. Dependent on the chosen installation type, you can also provision the cluster nodes.

[Step 1 - Establish infrastructure](/doc/vmware-step-1-prepare-Infrastructure.md)

## Step 2  - Prepare for OpenShift installation
The document below guides you through preparation of the bastion node and installing OpenShift. Choose the appropriate document for the infrastructure you have chosen to install on. In the below steps you will prepare the bastion node of the cluster and instantiate the required services such as DNS, NFS, NTP, to start the installation of OpenShift.

[Step 2 - Prepare and install OpenShift](/doc/vmware-step-2-prepare-openshift-installation.md)

## Step 3 - Install OpenShift (manual)
Once the bastion node has been prepared, continue with the installation of OpenShift.

[Step 3 - Install OpenShift](/doc/vmware-step-3-install-openshift.md)

## Step 4 - Define storage (manual)
Now, create the storage class(es) and set the storage to be used for the applications and the image registry.

[Step 4 - Define storage](/doc/vmware-step-4-define-storage.md)

## Step 5 - Finalize installation (manual)
You can finalize the OpenShift installation by executing the steps in the document below.

[Step 5 - Post-installation](/doc/vmware-step-5-post-install.md)

## Step 6 - Install the Cloud Pak
The below list links to the installation steps of various Cloud Paks, provided by IBM Cloud Pak technical specialists. It is by no means intended to replace the official documentation, but meant to accelerate the deployment of the Cloud Pak for POC and demo purposes.

* [Cloud Pak for Data 3.5](/doc/install-cp4d-35.md)