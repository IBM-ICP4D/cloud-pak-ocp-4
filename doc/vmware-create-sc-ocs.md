# Setting up OCS on an OCP 4.x installation provisioned on VMWare

Using steps found here: https://access.redhat.com/documentation/en-us/red_hat_openshift_container_storage/4.3/html/deploying_openshift_container_storage/deploying-openshift-container-storage, specifically **Installing OpenShift Container Storage using local storage devices**

## Pre-requisites
The steps in this document assume you have 3 (dedicated) worker nodes in the cluster, each with:
- 10 GB raw disk (for MON)
- Additional large raw disk (for Ceph). In the example below the disks are sized 200 GB

## Log in to OpenShift
```
oc login -u admin -p passw0rd
```

## Add labels to the workers
```
oc label nodes worker-1.ocp43.uk.ibm.com cluster.ocs.openshift.io/openshift-storage="" --overwrite
oc label nodes worker-2.ocp43.uk.ibm.com cluster.ocs.openshift.io/openshift-storage="" --overwrite
oc label nodes worker-3.ocp43.uk.ibm.com cluster.ocs.openshift.io/openshift-storage="" --overwrite
```

## Create namespace for local storage
```
oc new-project local-storage
```

## Create `openshift-storage` namespace
```
cat << EOF > /tmp/openshift-storage-ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    openshift.io/cluster-monitoring: "true"
  name: openshift-storage
EOF

oc apply -f /tmp/openshift-storage-ns.yaml
```

## Install local storage operator
You can install the operator using the OpenShift console or through the command line.

### Install operator via OpenShift console
- Open OpenShift console
- Go to Administrator --> Operators --> OperatorHub
- Find `Local Storage`
- Install
- Specify namespace `local-storage`
- Update channel: 4.4

### Create local-storage operator using CLI
```
cat << EOF > /tmp/local-storage-operator-group.yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: local-storage-operator-group
  namespace: local-storage
spec:
  targetNamespaces:
  - local-storage
EOF

cat <<EOF > /tmp/local-storage-operator.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  generation: 1
  name: local-storage-operator
  namespace: local-storage
  resourceVersion: '1293844'
  selfLink: >-
    /apis/operators.coreos.com/v1alpha1/namespaces/local-storage/subscriptions/local-storage-operator
spec:
  channel: '4.4'
  installPlanApproval: Automatic
  name: local-storage-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: local-storage-operator.4.4.0-202005252114
EOF

oc apply -f /tmp/local-storage-operator-group.yaml
oc apply -f /tmp/local-storage-operator.yaml
```

## Wait until the operator is running
```
watch -n 5 "oc get po -n local-storage"
```

## Create local-file storage class for MON
The `devicePaths` should list the path to the 10 GB disks that will be used for the MON metadata.
```
cat << EOF > /tmp/local-storage-file.yaml
apiVersion: local.storage.openshift.io/v1
kind: LocalVolume
metadata:
 name: local-file
 namespace: local-storage
spec:
 nodeSelector:
   nodeSelectorTerms:
   - matchExpressions:
       - key: cluster.ocs.openshift.io/openshift-storage
         operator: In
         values:
         - ""
 storageClassDevices:
   - storageClassName: localfile
     volumeMode: Filesystem
     devicePaths:
       - /dev/sdb
EOF

oc create -f /tmp/local-storage-file.yaml
```

## Create storage class for the Ceph file system
The `devicePaths` should list the path to the large disks that will be used for the data.
```
cat << EOF > /tmp/local-storage-block.yaml
apiVersion: local.storage.openshift.io/v1
kind: LocalVolume
metadata:
  name: local-block
  namespace: local-storage
spec:
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
        - /dev/sdc
EOF

oc apply -f /tmp/local-storage-block.yaml
```

Wait until PVs for `localblock-sc` storage class have been created; each PV is 200 GB.
```
watch -n 5 'oc get pv'
```

## Install OCS operator
You can install the operator using the OpenShift console or through the command line.

### Install OCS operator from web interface
- Open OpenShift
- Go to Administrator --> Operators --> OperatorHub
- Find `OpenShift Container Storage`
- Install
- Specify namespace `openshift-storage`
- Update channel: stable-4.3


### Install OCS operator using CLI
```
cat << EOF > /tmp/ocs-operator-group.yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ocs-operator-group
  namespace: openshift-storage
spec:
  targetNamespaces:
  - openshift-storage
EOF

cat << EOF > /tmp/ocs-operator.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ocs-operator
  namespace: openshift-storage
spec:
  channel: stable-4.3
  installPlanApproval: Automatic
  name: ocs-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: ocs-operator.v4.3.0
EOF

oc apply -f /tmp/ocs-operator-group.yaml
oc apply -f /tmp/ocs-operator.yaml
```

## Wait until the pods are running
```
watch -n 5 "oc get po -n openshift-storage"
```

Expected output:
```
Every 5.0s: oc get po -n openshift-storage                                                                                                        Wed Jun  3 05:14:15 2020

NAME                                      READY   STATUS    RESTARTS   AGE
lib-bucket-provisioner-5949bb554d-pqqqn   1/1     Running   0          8h
noobaa-operator-c8f5c9779-f42rb           1/1     Running   0          8h
ocs-operator-65fff9f8b4-6qdtc             1/1     Running   0          8h
rook-ceph-operator-54ff5c65cd-4qmgw	  1/1     Running   0          8h
```

## Create storage cluster
```
cat << EOF > /tmp/ocs-storagecluster.yaml
apiVersion: ocs.openshift.io/v1
kind: StorageCluster
metadata:
  name: ocs-storagecluster
  namespace: openshift-storage
spec:
  manageNodes: false
  monPVCTemplate:
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 10Gi
        storageClassName: localfile
        volumeMode: Filesystem
  storageDeviceSets:
  - count: 1
    dataPVCTemplate:
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Ti
        storageClassName: localblock
        volumeMode: Block
    name: ocs-deviceset
    placement: {}
    portable: true
    replica: 3
    resources: {}
EOF

oc apply -f /tmp/ocs-storagecluster.yaml
```

## Wait until all pods are up and running
```
watch -n 5 'oc get pod -n openshift-storage'
```

Wait until the OCS operator pod `ocs-operator-xxxxxxxx-yyyyy` is running with READY=`1/1`. You will see more than 20 pods starting in the `openshift-storage` namespace.

## Record name of storage class(es)
Now that the OCS operator has been created you should have a `ocs-storagecluster-cephfs` storage class which you can use for the internal image registry and other purposes.