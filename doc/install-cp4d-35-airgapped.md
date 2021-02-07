# Air-gapped installation of Cloud Pak for Data 3.5 on Red Hat OpenShift
These steps help to prepare the installation of Cloud Pak for Data 3.5 in air-gapped mode, in case the OpenShift cluster is not connected to the internet.

In essence you will first have to download all the services you want to install and then ship these to the bastion node from which you can continue to push the images to the registry and do the installation.

## Download Cloud Pak for Data

### Log on to the download node
Ensure that you're logged on to a machine which can run the cpd-<operating system> command. This can be a Linux server or a Windows or Mac workstation. In the steps below we're assuming you will be running the the download on a Linux server that is connected to the internet.

### Download installer
```
wget https://github.com/IBM/cpd-cli/releases/download/v3.5.2/cpd-cli-linux-EE-3.5.2.tgz -P /tmp/
mkdir -p /nfs/cpd
tar xvf /tmp/cpd-cli-linux-EE-3.5.2.tgz -C /nfs/cpd
rm -f /tmp/cpd-cli-linux-EE-3.5.2.tgz
```

### Obtain your entitlement key for the container registry
Login here: https://myibm.ibm.com/products-services/containerlibrary, using your IBMid. Then copy the entitlement key. 

### Apply key to the repo.yaml file
Insert the entitlement key after the `apikey:` parameter in the `/cp4d_download/cpd/repo.yaml` file. Please make sure you leave a blank after the `:`.

### Download Cloud Pak for Data services - individual assemblies
Use the steps below if you want to install Cloud Pak for Data with selective modules.

#### Download Cloud Pak for Data Lite
```
cd /cp4d_download/cpd
assembly="lite"
./cpd-cli preload-images --assembly $assembly --repo ./repo.yaml --action download --accept-all-licenses
```

#### Download other assemblies
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

If you want to download an assembly that is not listed above, find the installation instructions here: https://www.ibm.com/support/producthub/icpdata/docs/view/services/SSQNUZ_current/cpd/svc/services.html?t=Add%20services&p=services.

### Download Cloud Pak for Data patches - individual assemblies
If you want to download patches for the assemblies, use the following steps. You can find available patches here: https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_current/patch/avail-patches.html

#### Download patch for Cloud Pak for Data Lite
```
cd /cp4d_download/cpd
assembly="lite"
./cpd-cli patch --assembly $assembly --repo ./repo.yaml --version 3.5.2 --patch-name cpd-3.5.2-lite-patch-1 --action download
```

### Download Cloud Pak for Data services - multiple assemblies
Alternatively, you can download all the assemblies you want to install later using the following steps.
```
assemblies="lite wsl wml wkc spss dods rstudio dv"
cd /cp4d_download/cpd
for assembly in $assemblies;do
  echo $assembly
  ./cpd-cli preload-images --assembly $assembly --repo ./repo.yaml --action download --accept-all-licenses
done
```

### Download Cloud Pak for Data patches - multiple assemblies
You can also download the patches for all the assemblies. You can find available patches here: https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_current/patch/avail-patches.html
```
for p in \
  "lite cpd-3.5.2-lite-patch-1" \
  "wsl cpd-3.5.2-ccs-patch-1" \
  "wsl cpd-3.5.1-wsl-patch-1" \
  ;do
  set -- $p 
  ./cpd-cli patch --assembly $1 --repo ./repo.yaml --version 3.5.2 --patch-name $2 --action download
done
```

### Tar the downloads directory on the downloads server
```
tar czf /tmp/cp4d_downloads.tar.gz /cp4d_downloads 
```

Ship the tar file (most-likely 100+ GB) to the bastion server. Continue with the steps documented here: [Install Cloud Pak for Data](/doc/install-cp4d-35.md)