# Setting up OCS on an OCP 4.x installation provisioned on VMWare

Using steps found here: https://access.redhat.com/documentation/en-us/red_hat_openshift_container_storage/4.5/html/deploying_openshift_container_storage_on_vmware_vsphere/deploy-using-local-storage-devices-vmware and here https://red-hat-storage.github.io/ocs-training/training/ocs4/ocs-localdevice-blog.html (for the infra nodes steps).

## Pre-requisites
The steps in this document assume you have 3 (dedicated) worker nodes in the cluster, each with one additional large raw disk (for Ceph). In the example below the disks are sized 200 GB

## Log in to OpenShift
```
oc login -u admin -p passw0rd
```

## Add labels to the workers
```
ocs_nodes='ocs-1.ocp45.uk.ibm.com ocs-2.ocp45.uk.ibm.com ocs-3.ocp45.uk.ibm.com"
for ocs_node in $ocs_nodes;do
  oc label nodes $ocs_node cluster.ocs.openshift.io/openshift-storage="" --overwrite
  oc label nodes $ocs_node node-role.kubernetes.io/infra="" --overwrite
  oc adm taint nodes $ocs_node node.ocs.openshift.io/storage="true":NoSchedule
done
```

## Install OCS operator
You can install the operator using the OpenShift console.

### Install OCS operator from web interface
- Open OpenShift
- Go to Administrator --> Operators --> OperatorHub
- Find `OpenShift Container Storage`
- Install
- Select `A specific namespace on the cluster`, namespace `openshift-storage` will be created automatically
- Update channel: stable-4.5
- Click Install

### Wait until the pods are running
```
watch -n 5 "oc get po -n openshift-storage"
```

Expected output:
```
Every 5.0s: oc get po -n openshift-storage

NAME                                 READY   STATUS    RESTARTS   AGE
noobaa-operator-69bb7cd87d-hdnt6     1/1     Running   0          75m
ocs-operator-6b66b56cf8-xbhgj        1/1     Running   0          75m
rook-ceph-operator-d9cccc9bc-mmf4z   1/1     Running   0          75m
```

## Create namespace for local storage
```
oc adm new-project local-storage
```

## Install local storage operator
You can install the operator using the OpenShift console.

### Install operator via OpenShift console
- Open OpenShift console
- Go to Administrator --> Operators --> OperatorHub
- Find `Local Storage`
- Install
- Specify namespace `local-storage`
- Update channel: 4.5
- Click Install

### Wait until the operator is running
```
watch -n 5 "oc get po -n local-storage"
```

## Create storage class for the Ceph file system
The `devicePaths` should list the path to the large disks that will be used for the data.
```
cat << EOF > /tmp/localblock.yaml
apiVersion: local.storage.openshift.io/v1
kind: LocalVolume
metadata:
  name: localblock
  namespace: local-storage
  labels:
    app: ocs-storagecluster
spec:
  tolerations:
  - key: "node.ocs.openshift.io/storage"
    value: "true"
    effect: NoSchedule
  nodeSelector:
    nodeSelectorTerms:
    - matchExpressions:
        - key: cluster.ocs.openshift.io/openshift-storage
          operator: In
          values:
          - ""
  storageClassDevices:
    - storageClassName: localblock
      volumeMode: Block
      devicePaths:
        - /dev/sdb
EOF

oc apply -f /tmp/localblock.yaml
```

Wait until PVs for `localblock` storage class have been created; each PV is 200 GB.
```
watch -n 5 'oc get pv'
```

## Create storage cluster
- Open OpenShift console
- Go to Administrator --> Operators --> Installed Operators
- Select `openshift-storage` project at the top of the screen
- Click the `OpenShift Container Storage` operator
- Click the `Storage Cluster` link (tab)
- Click `Create OCS Cluster Service`
- Select `Internal` for mode
- The 3 storage nodes that were labelled before should already be selected
- Select `localblock` for Storage Class
- Click `Create`

## Wait until all pods are up and running
```
watch -n 5 'oc get pod -n openshift-storage'
```

Wait until the OCS operator pod `ocs-operator-xxxxxxxx-yyyyy` is running with READY=`1/1`. You will see more than 20 pods starting in the `openshift-storage` namespace.

## Add universal toleration to CSI plug-ins
If you install any components which require nodes to be tainted (such as Db2 Event Store), you need to add universal toleration to the OCS DaemonSets, as documented here: https://access.redhat.com/solutions/5061861.
```
oc patch ds csi-cephfsplugin -n openshift-storage  --type=merge -p '{"spec": {"template": { "spec": {"tolerations":[{"operator":"Exists"}]}}}}'
oc patch ds csi-rbdplugin -n openshift-storage  --type=merge -p '{"spec": {"template": { "spec": {"tolerations":[{"operator":"Exists"}]}}}}'
```

## Record name of storage class(es)
Now that the OCS operator has been created you should have a `ocs-storagecluster-cephfs` storage class which you can use for the internal image registry and other purposes.