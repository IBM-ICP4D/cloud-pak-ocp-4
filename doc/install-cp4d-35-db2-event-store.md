# Install Db2 Event Store
This document lists the steps to configure a Cloud pak for Data cluster to include the Db2 Event Store. Special steps are needed to taint the nodes, prepare the local volumes and ensure they are mounted at boot.

## Configure nodes for Db2 Event Store

### Specify 3 event store nodes
```
es_nodes="es-1.ocp45.uk.ibm.com es-2.ocp45.uk.ibm.com es-3.ocp45.uk.ibm.com"
```

### Taint and label the nodes
```
for node_name in $es_nodes;do
  oc adm taint node $node_name icp4data=database-db2eventstore:NoSchedule --overwrite
  oc label node $node_name icp4data=database-db2eventstore --overwrite
  oc label node $node_name node-role.db2eventstore.ibm.com/control=true --overwrite
done
```

### Check that nodes have been labeled correctly
```
oc get no -l icp4data=database-db2eventstore
```

### Format Event Store local disks
We will use logical volumes to make it easier to expand if needed.
```
for es_node in $es_nodes;do
  ssh core@$es_node 'sudo pvcreate /dev/sdb;sudo vgcreate es /dev/sdb;sudo lvcreate -l 100%FREE -n es_local es;sudo mkfs.xfs /dev/es/es_local'
done
```

### Create MCP for Event Store nodes
```
cat << EOF > /tmp/es_mcp.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: db2eventstore
spec:
  machineConfigSelector:
    matchExpressions:
      - {key: machineconfiguration.openshift.io/role, operator: In, values: [worker,db2eventstore]}
  maxUnavailable: 1
  nodeSelector:
    matchLabels:
      icp4data: database-db2eventstore
  paused: false
EOF
```

### Create machine config for Event Store nodes
```
cat << EOF > /tmp/es_mc_local_mount.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: db2eventstore
  name: 50-db2eventstore-local-mount
spec:
  config:
    ignition:
      version: 2.2.0
    systemd:
      units:
        - contents: |
            [Service]
            Type=oneshot
            ExecStartPre=/usr/bin/mkdir -p /mnt/es_local
            ExecStart=/usr/bin/mount /dev/es/es_local /mnt/es_local
            [Install]
            WantedBy=muti-user.target
          name: es-local-mount.service
          enabled: true
EOF
```

### Create configs
```
oc create -f /tmp/es_mcp.yaml
oc create -f /tmp/es_mc_local_mount.yaml
```

### Wait until Event Store nodes have been assigned to the correct MCP
```
watch -n 10 oc get mcp
```

Output:
```
[root@bastion bin]# watch -n 10 oc get mcp
Every 10.0s: oc get mcp                                                                                                                                                             Thu Jun 18 05:24:44 2020

NAME            CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT
db2eventstore                                                      False     True       False      3              0                   0                     0
master          rendered-master-0d397032dda301ab303ac43f25eea268   True      False      False      3              3                   3                     0
worker          rendered-worker-e94e7b0ff3b8923b16de48ce4f4d2520   True      False      False      3              3                   3                     0
```

Wait until the `db2eventstore ` machine config pool has `READYMACHINECOUNT=3`.

### Now you can create the Db2 Event Store instance
* Specify `database-db2eventstore` for the node label
* Specify `/mnt/es_local` for the `Local storage path`

### Check the status of the pods
```
oc get po -l component=eventstore
```

Output:
```
[root@bastion bin]# oc get po -l component=eventstore
NAME                                                          READY   STATUS     RESTARTS   AGE
db2eventstore-1592454732439-dm-backend-647d859cbf-6lkk6       0/1     Running    0          95s
db2eventstore-1592454732439-dm-frontend-8f7967797-xq7zj       1/1     Running    0          95s
db2eventstore-1592454732439-tenant-catalog-779fd765f8-ffh6n   0/1     Pending    0          95s
db2eventstore-1592454732439-tenant-engine-74c448467-fzxtb     0/1     Init:2/6   0          94s
db2eventstore-1592454732439-tenant-engine-74c448467-phv2c     0/1     Init:2/6   0          95s
db2eventstore-1592454732439-tenant-engine-74c448467-trvsj     0/1     Init:1/6   0          94s
db2eventstore-1592454732439-tenant-tools-6b667c5b5-v5pps      0/1     Running    0          95s
db2eventstore-1592454732439-tenant-zk-0                       0/1     Pending    0          95s
db2eventstore-1592454732439-tenant-zk-1                       0/1     Pending    0          94s
db2eventstore-1592454732439-tenant-zk-2                       0/1     Pending    0          94s
db2eventstore-1592454732439-tools-slave-56c98576c5-9gmxp      0/1     Init:1/3   0          94s
db2eventstore-1592454732439-tools-slave-56c98576c5-rq7q7      0/1     Init:1/3   0          94s
db2eventstore-1592454732439-tools-slave-56c98576c5-txxt7      0/1     Init:1/3   0          95s
```

No need to worry if you see pods with status `Pending` or even `ConfigError`, those statuses are typically transient.