# Set the resource quota for a namespace to stop the Cloud Pak
You can use this procedure to change the resource quota for a project to 0 and to stop all processing in that namespace, effectively stopping the Cloud Pak. This may be useful when templating a cluster or when you have multiple patterns defined on the same cluster, but want to activate only one.

## Stopping the processing in a project

### Create resourcequota object
```
cat << EOF > /tmp/rq-0.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources-0
spec:
  hard:
    pods: "0"
EOF
```

### Set resource quota for project
```
oc apply -n zen -f /tmp/rq-0.yaml
```

### Delete all pods in project
```
oc delete po -n zen --all
```

Now wait for all pods to stop.

## Restart processing in a project

### Remove the resource quota for the project
```
oc delete resourcequota -n zen compute-resources-0
```

### Watch application come up
It may take a few seconds (sometimes more) for the scheduler to start the pods in the namespace.
```
watch -n 10 'oc get po -n zen'
```
