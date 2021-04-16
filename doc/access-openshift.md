# Accessing Red Hat OpenShift Console

Once the Red Hat OpenShift cluster has been instantiated, you will probably want to access the console to add applications or to monitor the cluster. OpenShift heavily depends on DNS to access the Admin Console, Applications Console and Cluster Console and in a production situation you would need to add the master to your DNS server and set up a wildcard DNS entry for the cluster console and other applications (such as Cloud Pak for Data).

## Access via your local browser
If you want to access OpenShift from your local browser, change the `/etc/hosts` file on your laptop and add the entries for the master node as shown below.

Example `/etc/hosts` entry:
```
<Load_Balancer_IP> console-openshift-console.apps.ocp45.coc.ibm.com oauth-openshift.apps.ocp45.coc.ibm.com
```

Once you have added this entry, navigate to the following address:
https://console-openshift-console.apps.ocp45.coc.ibm.com 

Log on using user `ocadmin` and password `passw0rd`.
