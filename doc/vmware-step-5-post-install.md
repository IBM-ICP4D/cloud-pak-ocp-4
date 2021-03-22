# Install OpenShift on VMWare - Step 5 - Post-install
The steps below guide you through the post-installation steps of OpenShift. It assumes that the OpenShift masters and workers are in **Ready** state.

## Post-install steps
The following script will clean up the PXE links and rebuild the known_hosts file.
```
/ocp_install/scripts/post_install.sh
```

Amongst others, the script may opt the cluster out from remote health checking. Applying these changes to all nodes will take some time. To wait for the cluster operators to become ready, run the following:
```
/ocp_install/scripts/wait_co_ready.sh
```

## Optional: Disable DHCP server
After the workers have been deployed, you may no longer need the DHCP server that is running on the bastion node. To avoid any conflicts with other activities on the VMWare infrastructure, you can now disable the DHCP service within  `dnsmasq`.
```
/ocp_install/scripts/disable_dhcp.sh
```

## Keep the cluster running for 24h
> **IMPORTANT:** After completing the OpenShift 4.x installation, ensure that you keep the cluster running for at least 24 hours. This is required to renew the temporary control plane certificates. If you shut down the cluster nodes before the control plane certificates are renewed and they expire while the cluster is down, you will not be able to access OpenShift.

## Access OpenShift (optional)
You can now access OpenShift by editing your `/etc/hosts` file. See [Access OpenShift](/doc/access-openshift.md) for more details.

## Continue with next step
You can now continue with the installation of one of the Cloud Paks.

[Step 6 - Install the Cloud Pak](/README.md#step-6---install-the-cloud-pak)
