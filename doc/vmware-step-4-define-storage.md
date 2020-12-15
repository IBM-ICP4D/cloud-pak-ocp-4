# Install OpenShift on VMWare - Step 4 - Define storage
Now that the cluster is up and running - from a processing perspective - you need to define storage classes and configure the OpenShift internal image registry to persist its content on that storage. Dependent on the Cloud Pak you will be installing, you can choose from using NFS, OCS/Ceph or Portworx.

## Create storage classes
For NFS, a script to create the `nfs-client` storage class will have been generated if you configured this in the inventory file. OCS/Ceph and Portworx currently require manual steps via the OpenShift console or the command line. Please note that you're not restricted to create only 1 storage class. If you have capacity on the the cluster and a matching configuration of disks, you can create multiple storage classes.

### Create NFS storage class
NFS is a convenient and easy to configure storage solution but not suitable for production in the POC/demo cluster setup. On the cluster, the bastion node also serves NFS with a single large volume used for both the image registry and storage defined for the Cloud Paks. It introduces a single point of failure for both of the above consumers, which we don't consider an issue for non-production use.

If you want to use NFS for any of the applications deployed on OpenShift, you can create a storage class `nfs-client`. This will attach the storage class to the server and NFS directory configured in the inventory file used when preparing the OpenShift installation.
```
/ocp_install/scripts/create_nfs_sc.sh
```

Once you have run the script, the provisioner will start in the `default` namespace and a storage class has been created:
```
[root@bastion cloud-pak-ocp-4]# oc get sc
NAME         PROVISIONER       AGE
nfs-client   icpd-nfs.io/nfs   4m18s
```

### Create OpenShift Container Storage - Ceph
As from version 4 of OpenShift, OpenShift Container Storage implements Ceph, a software defined storage (SDS) solution that has been available as a storage backend for Kubernetes and OpenStack for a number of years. OCS/Ceph provides a distributed file system that can handle node failures and also has better performance characteristics than NFS.

On the demo infrastructure, an empty raw volume has been created on the worker nodes. This can be used to deploy OCS.

To create the OCS/Ceph storage class, please refer to [OCS Storage Class](/doc/vmware-create-sc-ocs.md).

## Define storage for image registry
During the installation of OpenShift, no container image registry has been created; this has to be done as a separate step and storage must be assigned to the image registry. Run the script that creates the persistent volume claim (PVC) for the image registry. The storage class to be used for the registry has been defined in the inventory file.
```
/ocp_install/scripts/create_registry_storage.sh
```

## Continue with next step
Now you can continue with the post-installation steps:

[VMWare - Step 5 - Post-installation steps](/doc/vmware-step-5-post-install.md)
