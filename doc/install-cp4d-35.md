# Install Cloud Pak for Data 3.5 on Red Hat OpenShift

These steps assume that Red Hat OpenShift 4.5 has already been installed on the cluster and a storage class for NFS, OCS or Portworx is available on the cluster.

## Prepare installation for Cloud Pak for Data

### Log on to the bastion node
Ensure that you're logged on to the bastion node as `root`.

## Use screen to multiplex your terminal
The `screen` utility allows you to perform a long-running task in a terminal, which continues even if your connection drops. Once started, you can use `Ctrl-A D` to detach from your screen and `screen -r` to return to the detached screen. If you accidentally started multiple screens, you can use `screen -ls` to list the screen sessions and then attach to one of them using `screen -r <session_id>`. As a best practice, try to have only one screen terminal active to simplify navigation.
```
screen
```

## Log on to OpenShift
If not already logged on, log on to the bastion node as `root`; this is the 2nd IP address in the Asset Access Instructions document.
```
oc login -s https://api.apps.ocp45.uk.ibm.com:6443 -u ocadmin -p passw0rd --insecure-skip-tls-verify=true
```

## Override CRI-O settings
```
cat << EOF > /tmp/cp4d-crc.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: ContainerRuntimeConfig
metadata:
  name: cp4d-crio-limits
spec:
  machineConfigPoolSelector:
    matchLabels:
      limits-crio: cp4d-crio-limits
  containerRuntimeConfig:
    pidsLimit: 12288
EOF

oc create -f /tmp/cp4d-crc.yaml

oc label mcp worker limits-crio=cp4d-crio-limits
```

## Override sysctl settings through Tuned
The steps below change the system control parameters required for WKC pods. These changes are typically required, regardless whether the WKC assembly is installed.
```
cat << EOF > /tmp/42-cp4d.yaml
apiVersion: tuned.openshift.io/v1
kind: Tuned
metadata:
  name: cp4d-wkc-ipc
  namespace: openshift-cluster-node-tuning-operator
spec:
  profile:
  - name: cp4d-wkc-ipc
    data: |
      [main]
      summary=Tune IPC Kernel parameters on OpenShift Worker Nodes running WKC Pods
      [sysctl]
      kernel.shmall = 33554432
      kernel.shmmax = 68719476736
      kernel.shmmni = 16384
      kernel.sem = 250 1024000 100 16384
      kernel.msgmax = 65536
      kernel.msgmnb = 65536
      kernel.msgmni = 32768
      vm.max_map_count = 262144
  recommend:
  - match:
    - label: node-role.kubernetes.io/worker
    priority: 10
    profile: cp4d-wkc-ipc
EOF

oc create -f /tmp/42-cp4d.yaml
```

## Wait until machine configurations have been applied
OpenShift will now apply the machine configurations to all the workers and reboot them one by one. This may take a while to complete and it is best to wait before you continue with the next step.
```
watch -n 10 'oc get mcp'
```

Machine configurations have been applied when "worker" line has UPDATED=True and UPDATING=False. You can see that the READYMACHINECOUNT column goes from 0 up to the number of workers. Example:
```
Every 10.0s: oc get mcp                                                                                                                                                                                                               Sun Sep  6 07:40:44 2020

NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
master   rendered-master-7e735cd7f00167b46e7e663d41634ced   True      False	 False      3              3                   3                     0                      17d
worker   rendered-worker-3bc6374bf0d550a75df4206e1bd94610   False     True	 False      3              1                   1                     0                      17d
```

If you want to check what is happening with the nodes, you can run the following command:
```
oc get no
```

Example:
```
[root@bastion ~]# oc get no
NAME                        STATUS                     ROLES    AGE   VERSION
master-1.ocp45.uk.ibm.com   Ready                      master   17d   v1.18.3+002a51f
master-2.ocp45.uk.ibm.com   Ready                      master   17d   v1.18.3+002a51f
master-3.ocp45.uk.ibm.com   Ready                      master   17d   v1.18.3+002a51f
worker-1.ocp45.uk.ibm.com   Ready                      worker   17d   v1.18.3+002a51f
worker-2.ocp45.uk.ibm.com   Ready,SchedulingDisabled   worker   17d   v1.18.3+002a51f
worker-3.ocp45.uk.ibm.com   Ready                      worker   17d   v1.18.3+002a51f
```

# Install Cloud Pak for Data (connected)
These steps assume that the OpenShift cluster is connected to the internet. If not, skip to [Air-gapped install of Cloud Pak for Data](#air-gapped-install-of-cloud-pak-for-data)

## Download installer
```
wget https://github.com/IBM/cpd-cli/releases/download/v3.5.2/cpd-cli-linux-EE-3.5.2.tgz -P /tmp/
mkdir -p /nfs/cpd
tar xvf /tmp/cpd-cli-linux-EE-3.5.2.tgz -C /nfs/cpd
rm -f /tmp/cpd-cli-linux-EE-3.5.2.tgz
```

## Obtain your entitlement key for the container registry
Login here: https://myibm.ibm.com/products-services/containerlibrary, using your IBMid. Then copy the entitlement key. 

## Apply key to the repo.yaml file
Insert the entitlement key after the `apikey:` parameter in the `/nfs/cpd/repo.yaml` file. Please make sure you leave a blank after the `:`.

# Install Cloud Pak for Data - individual modules
Use the steps below if you want to install Cloud Pak for Data with selective modules.

### Create OCP project for individual modules
```
oc new-project zen
oc project zen # Ignore the warning message if you get one
```

### Install Cloud Pak for Data Lite
```
cd /nfs/cpd
./cpd-cli adm --assembly lite --namespace zen --repo ./repo.yaml --apply --accept-all-licenses
./cpd-cli install --assembly lite --namespace zen --repo ./repo.yaml --storageclass nfs-client --transfer-image-to=$(oc registry info)/zen --target-registry-username=$(oc whoami) --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix=image-registry.openshift-image-registry.svc:5000/zen --latest-dependency --accept-all-licenses
```

### List available patches
```
cd /nfs/cpd
./cpd-cli status -a lite -n zen -r ./repo.yaml --patches --available-updates
```

### Apply patch
Find the latest patch applicable to the Lite assembly and apply.
```
PATCH_NAME="patch_name"
./cpd-cli patch -a lite -n zen --patch-name $PATCH_NAME --transfer-image-to=$(oc registry info)/zen -r ./repo.yaml --target-registry-username=$(oc whoami) --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix=image-registry.openshift-image-registry.svc:5000/zen
```

### Access Cloud Pak for Data
Once the installation of the *Lite* assembly has finished, you can access Cloud Pak for Data via the following URL: https://zen-cpd-zen.apps.ocp45.uk.ibm.com. To ensure your computer can resolve the host name, add an entry to the `/etc/hosts` file:
```
<bastion IP> zen-cpd-zen.apps.ocp45.uk.ibm.com
```

### Install Watson Studio
```
assembly="wsl"
cd /nfs/cpd
./cpd-cli adm -a $assembly --repo ./repo.yaml --namespace zen --apply --accept-all-licenses
./cpd-cli install -a $assembly -n zen -c nfs-client --transfer-image-to=$(oc registry info)/zen -r ./repo.yaml --target-registry-username=$(oc whoami) --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix=image-registry.openshift-image-registry.svc:5000/zen --accept-all-licenses
```

### List available patches
```
./cpd-cli status -a $assembly -n zen -r ./repo.yaml --patches --available-updates
```

### Apply patch
Find the latest patch applicable to the WSL assembly and apply.
```
PATCH_NAME="patch_name"
./cpd-cli patch -a wsl -n zen --patch-name $PATCH_NAME --transfer-image-to=$(oc registry info)/zen -r ./repo.yaml --target-registry-username=$(oc whoami) --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix=image-registry.openshift-image-registry.svc:5000/zen
```

### Install other assemblies
You can repeat the above steps for the other assemblies, each time by selecting a different assembly name, for example:
```
assembly="wml"
...
```
* Watson Machine Learning: wml
* Watson Knowledge Catalog: wkc
* Data Virtualization: dv
* Db2 Warehouse: db2wh
* Db2 Event Store: db2eventstore
* SPSS Modeler: spss-modeler
* Decision Optimization: dods
* Cognos Analytics: ca
* DataStage: ds

If you want to install an assembly that is not listed above, find the installation instructions here: https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_latest/svc-nav/head/services.html.

> Some assemblies like Watson Discovery require a different storage class or other overrides which can be specified with an override. Please refer to the installation instructions of the specific service for more information.

## Install multiple assemblies in one go
If you want to install multiple assemblies in a single go, you can execute in a for-loop. Please ensure that the assemblies do not require special overrides such as Spark.
```
assemblies="lite wsl wml wkc spss dods rstudio dv"
cd /nfs/cpd
for assembly in $assemblies;do
  echo $assembly
  ./cpd-cli adm -a $assembly --repo ./repo.yaml --namespace zen --apply --accept-all-licenses
  ./cpd-cli install -a $assembly -n zen -c nfs-client --transfer-image-to=$(oc registry info)/zen -r ./repo.yaml --target-registry-username=$(oc whoami) --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix=image-registry.openshift-image-registry.svc:5000/zen --cluster-pull-username=$(oc whoami) --cluster-pull-password=$(oc whoami -t) --accept-all-licenses
done
```

### Prepare installation of Db2 Event Store
If you intend to install Db2 Event Store on the cluster, you need to allocate 3 dedicated nodes for this. Preparation instructions can be found here: [Db2 Event Store preparation](/doc/install-cp4d-35-db2-event-store.md).

# Air-gapped install of Cloud Pak for Data

## Unpack the downloaded tar file
```
tar xzf /tmp/cp4d_downloads.tar.gz -C / 
```

## Install Cloud Pak for Data

### Create OCP project
```
oc new-project zen
oc project zen # Ignore the warning message if you get one
```

### Install Cloud Pak for Data Lite
```
cd /cp4d_downloads/cpd
./cpd-cli adm --assembly lite --namespace zen --load-from ./cpd-linux-workspace --apply --accept-all-licenses
./cpd-cli preload-images --assembly lite --version 3.5.1 --load-from ./cpd-linux-workspace --action push --transfer-image-to=$(oc registry info)/zen --target-registry-username=$(oc whoami) --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --accept-all-licenses
./cpd-cli --assembly lite --version 3.5.1 --namespace zen --load-from ./cpd-linux-workspace --storageclass nfs-client --cluster-pull-prefix image-registry.openshift-image-registry.svc:5000/zen --accept-all-licenses
```

### Install Cloud Pak for Data Lite patch
```
PATCH_NAME="patch_name"
./cpd-cli patch --assembly lite --namespace zen --version 3.5.1 --patch-name $PATCH_NAME --load-from ./cpd-linux-workspace --action push --transfer-image-to=$(oc registry info)/zen --target-registry-username=$(oc whoami) --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix=image-registry.openshift-image-registry.svc:5000/zen
```

Repeat for the other services you want to install.