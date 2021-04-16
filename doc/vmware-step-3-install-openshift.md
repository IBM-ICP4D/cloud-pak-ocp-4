# Install OpenShift on VMWare - Step 3 - Install OpenShift
The steps below guide you through the installation of the OpenShift cluster. It assumes that the bastion node of the cluster has already been prepared in the previous step.

## Start all cluster nodes
Go to the vSphere web interface of your ESX infrastructure and log in.

Find the VM folder that holds the cluster VMs and start the bootstrap, masters and workers.

![vSphere Start control plane](/images/vsphere-start-nodes.png)

## Wait for bootstrap to complete
The bootstrapping of the control plane can take up to 30 minutes. Run the following command to wait for the bootstrapping to complete.
```
/ocp_install/scripts/wait_bootstrap.sh
```

You should see something like this:
```
INFO Waiting up to 30m0s for the Kubernetes API at https://api.ocp45.coc.ibm.com:6443...
INFO API v1.16.2 up
INFO Waiting up to 30m0s for bootstrapping to complete...
INFO It is now safe to remove the bootstrap resources
```

If you want the output to be a bit more verbose, especially while waiting for the first step to complete, you can run the script as follows:
```
/ocp_install/scripts/wait_bootstrap.sh --log-level=debug
```

## Remove bootstrap from load balancer
Now that the control plane has been started, the bootstrap is no longer needed. Execute the following step to remove the references to the bootstrap node from the load balancer and shut down the bootstrap node. After that you can remove the bootstrap VM from within vSphere.
> If you're not managing the load balancer from/on the bastion node, you have to manually remove or comment out the bootstrap entries.
```
/ocp_install/scripts/remove_bootstrap.sh
```

## Approve Certificate Signing Requests and wait for nodes to become ready
Run the following to approve CSRs of the workers and wait for the nodes to become Ready.
```
/ocp_install/scripts/wait_nodes_ready.sh
```

Alternatively, you can manually approve the certificates.
```
export KUBECONFIG=/ocp_install/auth/kubeconfig
oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs --no-run-if-empty oc adm certificate approve
oc get no
```

Repeat the `oc get csr` and `oc get no` commands until you see all workers added to your cluster.

## Create OpenShift administrator user
Rather than using `kubeadmin` to operate OpenShift, we're creating an OpenShift administrator user. The script below will create the `ocadmin` user with the password that was set in the environment variable `ocp_admin_password`.
```
/ocp_install/scripts/create_admin_user.sh
```

You can ignore the `Warning: User 'ocadmin' not found` message. Once the script has run, a new authentication mechanism will be added to the `authentication` cluster operator. This will take a few minutes and only once finished you can log on with the `ocadmin` user.

## Wait for installation to complete
Now wait for the installation to complete. This should be very quick, but could take up to 30 minutes.
```
/ocp_install/scripts/wait_install.sh
```

Something like the following should be displayed:
```
INFO Waiting up to 30m0s for the cluster at https://api.ocp45.coc.ibm.com:6443 to initialize...
INFO Waiting up to 10m0s for the openshift-console route to be created...
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/ocp_install/auth/kubeconfig'
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.ocp45.coc.ibm.com
INFO Login to the console with user: kubeadmin, password: Fo9wP-taw47-6ujnV-jwT2k
```

**Please note that the above output renders the `kubeadmin` password**

## Wait for all cluster operators to become ready
To wait for the cluster operators to become ready, run the following script:
```
/ocp_install/scripts/wait_co_ready.sh
```

Alternatively, you can monitor the cluster operators by running the following command.
```
watch -n 10 'oc get co'
```
The deployment has been completed if AVAILABLE=True and PROGRESSING=False for all cluster operators.

Once complete, you can log on as below.
```
unset KUBECONFIG
API_URL=$(grep "api-int" /etc/dnsmasq.conf | sed 's#.*\(api.*\)/.*#\1#')
oc login -s $API_URL:6443 -u admin -p passw0rd --insecure-skip-tls-verify=true
```

The password above might be different for you.

## Continue with next step
Now that the masters and workers are running, we can defin the storage to be used for the applications and image registry.

[VMWare - Step 4 - Define storage](/doc/vmware-step-4-define-storage.md)

## What's happening during the OpenShift installation?
If you want to know what is happening during the installation of the control plane, check here: [Explanation of OpenShift installation procedure](/doc/ocp-step-3-install-openshift-explanation.md)
