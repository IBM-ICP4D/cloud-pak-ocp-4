# Setting up OCS on an OCP 4.x installation provisioned on VMWare with local storage on the workers

Using steps found here: https://access.redhat.com/documentation/en-us/red_hat_openshift_container_storage/4.6/html/deploying_openshift_container_storage_on_vmware_vsphere/deploy-using-local-storage-devices-vmware.

## Pre-requisites
The steps in this document assume you have 3 (dedicated) worker nodes in the cluster, each with one additional large raw disk (for Ceph). In the example below the disks are sized 200 GB

## Log in to OpenShift
```
oc login -u ocadmin -p passw0rd
```

## Add labels and taints to the workers
```
ocs_nodes='ocs-1.ocp46.uk.ibm.com ocs-2.ocp46.uk.ibm.com ocs-3.ocp46.uk.ibm.com'
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
- Update channel: stable-4.6
- Click Install

### Wait until the pods are running
```
watch -n 5 "oc get po -n openshift-storage"
```

Expected output:
```
NAME                                    READY   STATUS    RESTARTS   AGE
noobaa-operator-7688b8849d-xzlgm        1/1     Running   0          37m
ocs-metrics-exporter-776fffcf89-w2hmq   1/1     Running   0          37m
ocs-operator-6b8455554f-frr89           1/1     Running   0          37m
rook-ceph-operator-6457794bc-zqbt7      1/1     Running   0          37m
```

## Install local storage operator
You can install the operator using the OpenShift console.

### Install operator via OpenShift console
- Open OpenShift console
- Go to Administrator --> Operators --> OperatorHub
- Find `Local Storage`
- Install
- Specify namespace `openshift-local-storage`
- Update channel: 4.6
- Click Install

### Wait until the operator is running
```
watch -n 5 "oc get csv -n openshift-local-storage"
```

## Create storage cluster
- Open OpenShift console
- Go to Administrator --> Opoerators --> Installed Operators
- Select `openshift-storage` as the project
- Click on OpenShift Container Storage
- Under Storage Cluster, click on Create instance
- Select `Internal - Attached Devices` for Mode
- Select nodes
- Select `ocs-1`, `ocs-2` and `ocs-3` and click Next
- Wait for a bit so that OpenShift can interrogate the workers
- Enter `local-volume-sdb` for the Volume Set Name
- Click Advanced and select the disk size, for example Min: 200 GiB, Max: 200 GiB
- Select `local-volume-sdb` for the Storage Class
- Click Create

Wait until PVs for `local-volume-sdb` storage class have been created; each PV is 200 GB.
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

OCS will also automatically create the Ceph storage classes.

## Wait until all pods are up and running
The storage cluster will be ready when the `ocs-operator` pod is ready.
```
watch -n 5 'oc get pod -n openshift-storage'
```

## Wait for the storage cluster to be created
```
watch -n 10 'oc get po -n openshift-storage
```

Wait until the OCS operator pod `ocs-operator-xxxxxxxx-yyyyy` is running with READY=`1/1`. You will see more than 20 pods starting in the `openshift-storage` namespace.

## Add toleration to CSI plug-ins
If you install any components which require nodes to be tainted (such as Db2 Event Store), you need to add additional tolerations for the OCS DaemonSets, which can be done via the `rook-ceph-operator-config` ConfigMap.

First, get the definition of the Configmap:
```
oc get cm -n openshift-storage rook-ceph-operator-config -o yaml > /tmp/rook-ceph-operator-config.yaml
```

Edit, the file to have the following value for the CSI_PLUGIN_TOLERATIONS data element:
```
data:
  CSI_PLUGIN_TOLERATIONS: |2-

    - key: node.ocs.openshift.io/storage
      operator: Equal
      value: "true"
      effect: NoSchedule
    - key: icp4data
      operator: Equal
      value: "database-db2eventstore"
      effect: NoSchedule
```

Apply the changes to the ConfigMap:
```
oc apply -f /tmp/rook-ceph-operator-config.yaml
```

You should notice that the CSI pods are now also scheduled on the Event Store nodes. This ConfigMap change will survive the restart of the rook operator.

## Record name of storage class(es)
Now that the OCS operator has been created you should have a `ocs-storagecluster-cephfs` storage class which you can use for the internal image registry and other purposes.