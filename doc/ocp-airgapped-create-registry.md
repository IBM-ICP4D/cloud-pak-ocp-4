# Create registry server for disconnected install
These instructions were derived from the Red Hat documentation: https://docs.openshift.com/container-platform/4.3/installing/install_config/installing-restricted-networks-preparations.html, with additional steps to also set up the downloads for the OpenShift installer, OpenShift client and Red Hat CoreOS dependencies and host them on a registry server.

If you follow these instructions, you will download all assets needed to run the `prepare.sh` script with an "airgapped" inventory file.

The way the steps are organized is that they allow you to create a registry server in a semi-airgapped manner (registry server is connected to the internet but OpenShift cluster is not), but also in a full air-gapped manner (registry server is not connected to the internet). If the registry server is connected to the internet, you can execute the download steps on the registry server as it has both roles.

> Please note that when the steps refer to **registry server**, we mean the VM or server that runs the **registry service** (container) and the HTTP server for the client and installer files.

There are 2 high-level steps that have to be executed:
* [Download assets for the registry](#download-assets-for-the-registry)
* [Serve the registry][#serve-the-registry]

# Download assets for the registry

## Connect to the download server
If you're doing a semi-airgapped install (your registry server can connect to the internet), the registry server also serves as the download server.

## Stop the firewall (if active)
```
systemctl stop firewalld;systemctl disable firewalld
```

## Install required packages
```
yum -y install wget podman httpd-tools jq
```

## Update the /etc/hosts file with the registry server information
If you are using a separate download server (full air-gapped install), you can avoid having to regenerate the self-signed certificate and tweak the json files, by temporarily adding the registry server in the `/etc/hosts` file. In the below example, the `download.ocp43.coc.ibm.com` server is connected to the internet and is used to download all packages and images; the `registry.ocp43.coc.ibm.com` is the server which is accessible from the OpenShift cluster. In reality, the `registry.ocp43.coc.ibm.com` server has IP address `10.99.92.61`.

```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
10.99.92.62 download.ocp43.coc.ibm.com registry.ocp43.coc.ibm.com
```

## Set environment variables
Make sure you adapt the variables below to your environment.
```
export REGISTRY_SERVER=registry.ocp43.coc.ibm.com
export REGISTRY_PORT=5000
export LOCAL_REGISTRY="${REGISTRY_SERVER}:${REGISTRY_PORT}"
export EMAIL="youruser@yourdomain.com"
export REGISTRY_USER="admin"
export REGISTRY_PASSWORD="passw0rd"

export OCP_RELEASE="4.3.31"
export RHCOS_RELEASE="4.3.33"
export LOCAL_REPOSITORY='ocp4/openshift4' 
export PRODUCT_REPO='openshift-release-dev' 
export LOCAL_SECRET_JSON='/ocp4_downloads/ocp4_install/ocp_pullsecret.json' 
export RELEASE_NAME="ocp-release"
```

## Prepare OpenShift download directory
```
mkdir -p /ocp4_downloads/{clients,dependencies,ocp4_install}
mkdir -p /ocp4_downloads/registry/{auth,certs,data,images}
```

## Retrieve OpenShift client and CoreOS downloads
You may have to go to the URLs holding the clients and dependencies to find the latest release.
```
cd /ocp4_downloads/clients
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.3/openshift-client-linux.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.3/openshift-install-linux.tar.gz
```

If you will install RHCOS using PXE boot:
```
cd /ocp4_downloads/dependencies
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/latest/rhcos-${RHCOS_RELEASE}-x86_64-metal.x86_64.raw.gz
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/latest/rhcos-${RHCOS_RELEASE}-x86_64-installer.x86_64.iso
```

Or, if you will be using a VM template (ova file) for the RHCOS installation:
```
cd /ocp4_downloads/dependencies
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/latest/rhcos-${RHCOS_RELEASE}-x86_64-vmware.x86_64.ova
```

## Install OpenShift client
```
tar xvzf /ocp4_downloads/clients/openshift-client-linux.tar.gz -C /usr/local/bin
```

## Generate certificate
```
cd /ocp4_downloads/registry/certs
openssl req -newkey rsa:4096 -nodes -sha256 -keyout registry.key -x509 -days 365 -out registry.crt -subj "/C=US/ST=/L=/O=/CN=$REGISTRY_SERVER"
```

## Create password for registry
Change the password to something more secure if you want to.
```
htpasswd -bBc /ocp4_downloads/registry/auth/htpasswd $REGISTRY_USER $REGISTRY_PASSWORD
```

## Download registry image
```
podman pull docker.io/library/registry:2
podman save -o /ocp4_downloads/registry/images/registry-2.tar docker.io/library/registry:2
```

## Download NFS provisioner image
```
podman pull quay.io/external_storage/nfs-client-provisioner:latest
podman save -o /ocp4_downloads/registry/images/nfs-client-provisioner.tar quay.io/external_storage/nfs-client-provisioner:latest
```

## Create registry pod
```
podman run --name mirror-registry --publish $REGISTRY_PORT:5000 \
     --detach \
     --volume /ocp4_downloads/registry/data:/var/lib/registry:z \
     --volume /ocp4_downloads/registry/auth:/auth:z \
     --volume /ocp4_downloads/registry/certs:/certs:z \
     --env "REGISTRY_AUTH=htpasswd" \
     --env "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
     --env REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
     --env REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
     --env REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
     docker.io/library/registry:2
```

## Add certificate to trusted store
```
/usr/bin/cp -f /ocp4_downloads/registry/certs/registry.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust
```

## Check if you can connect to the registry
```
curl -u $REGISTRY_USER:$REGISTRY_PASSWORD https://${LOCAL_REGISTRY}/v2/_catalog
```

Output should be:
```
{"repositories":[]}
```

## Create pull secret file
Create file `/tmp/ocp_pullsecret.json` and insert the contents of the pull secret you retrieved from: https://cloud.redhat.com/openshift/install/vsphere/user-provisioned.

## Generate air-gapped pull secret
The air-gapped pull secret will be used when installing OpenShift.
```
AUTH=$(echo -n "$REGISTRY_USER:$REGISTRY_PASSWORD" | base64 -w0)

CUST_REG='{"%s": {"auth":"%s", "email":"%s"}}\n'
printf "$CUST_REG" "$LOCAL_REGISTRY" "$AUTH" "$EMAIL" > /tmp/local_reg.json

jq --argjson authinfo "$(</tmp/local_reg.json)" '.auths += $authinfo' /tmp/ocp_pullsecret.json > /ocp4_downloads/ocp4_install/ocp_pullsecret.json
```

The contents of the `/ocp4_downloads/ocp4_install/ocp_pullsecret.json` should be something like this:
```
{
  "auths": {
    "cloud.openshift.com": {
      "auth": ...,
      "email": "fketelaars@nl.ibm.com"
    },
    "quay.io": {
      "auth": ...,
      "email": "fketelaars@nl.ibm.com"
    },
    "registry.connect.redhat.com": {
      "auth": ...,
      "email": "fketelaars@nl.ibm.com"
    },
    "registry.redhat.io": {
      "auth": ...,
      "email": "fketelaars@nl.ibm.com"
    },
    "registry.ocp43.coc.ibm.com:5000": {
      "auth": "YWRtaW46cGFzc3cwcmQ=",
      "email": "youruser@yourdomain.com"
    }
  }
}
```

## Mirror registry
This takes 5-10 minutes to complete.
```
oc adm -a ${LOCAL_SECRET_JSON} release mirror \
     --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-x86_64 \
     --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
     --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}
```

Output:
```
imageContentSources:
- mirrors:
  - registry.ocp43.coc.ibm.com:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - registry.ocp43.coc.ibm.com:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```

## Package up downloads directory and ship it to the registry server
> **Do this only if your registry server cannot be connected to the internet.**

If your registry server cannot be connected to the internet, you will have to create a tar ball and send it to the registry server. If you have performed the steps above on the registry server (semi-airgapped install), you can skip the steps below and continue with [Serve the registry](#serve-the-registry).

### Stop the registry
```
podman rm -f mirror-registry
```

### Remove the registry server from the /etc/hosts file
You can now remove the registry server entry from the `/etc/hosts` file on the download server, if you used a separate download server.

### Tar the downloads directory on the downloads server
This will create a tar ball of ~5GB.
```
tar czf /tmp/ocp4_downloads.tar.gz /ocp4_downloads 
```

### Send the tar ball to the registry server
The way the tar ball is shipped is dependent on how the registry server can be reached. Either `scp`, some kind if shared folder or plain USB sticks may have to be used.

# Serve the registry

## Log on to the registry server

## Stop the firewall (if active)
```
systemctl stop firewalld;systemctl disable firewalld
```

## Install required packages
```
yum -y install wget podman httpd-tools jq nginx
```

## Check and adapt the /etc/hosts file
Check the /etc/hosts file and ensure that it has the correct entry for the registry server, such as:
```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
10.99.92.61     registry.ocp43.coc.ibm.com registry
```

## Untar the tar ball on the registry server
You will only have to do this if your registry server cannot connect to the internet and you executed the above steps on a separate download server.
```
tar xzf /tmp/ocp4_downloads.tar.gz -C /
```

### Set environment variables
```
export REGISTRY_SERVER=$(hostname -f)
export REGISTRY_PORT=5000

export LOCAL_REGISTRY="${REGISTRY_SERVER}:${REGISTRY_PORT}"
export REGISTRY_USER="admin"
export REGISTRY_PASSWORD="passw0rd"

export LOCAL_REPOSITORY='ocp4/openshift4'
export LOCAL_SECRET_JSON='/ocp4_downloads/ocp4_install/ocp_pullsecret.json'
```

### Create registry pod on the new registry server
```
podman load -i /ocp4_downloads/registry/images/registry-2.tar
podman run --name mirror-registry --publish $REGISTRY_PORT:5000 \
     --detach \
     --volume /ocp4_downloads/registry/data:/var/lib/registry:z \
     --volume /ocp4_downloads/registry/auth:/auth:z \
     --volume /ocp4_downloads/registry/certs:/certs:z \
     --env "REGISTRY_AUTH=htpasswd" \
     --env "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
     --env REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
     --env REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
     --env REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
     docker.io/library/registry:2
```

### Add certificate to trusted store on the new registry server
```
/usr/bin/cp -f /ocp4_downloads/registry/certs/registry.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust
```

## Check if you can connect to the registry
```
curl -u $REGISTRY_USER:$REGISTRY_PASSWORD https://${LOCAL_REGISTRY}/v2/_catalog
```

The output should be as follows (as the registry now has content):
```
{"repositories":["ocp4/openshift4"]}
```

## Create systemd unit file to ensure the registry is started after reboot
```
podman generate systemd mirror-registry -n > /etc/systemd/system/container-mirror-registry.service
systemctl enable container-mirror-registry.service
systemctl daemon-reload
```

## Configure and start the http server

### Change nginx config
Make the following changes to `/etc/nginx/nginx.conf`.

Change the default port number of 80 to 8080.
```
    server {
        listen       8080 default_server;
```

Add another location under the `/` location that is already there.
```
        location /ocp4_downloads {
            autoindex on;
        }
```

Create symbolic link
```
ln -s /ocp4_downloads /usr/share/nginx/html/ocp4_downloads
```

### Start nginx
```
systemctl restart nginx;systemctl enable nginx
```

### Check that we can list entries
```
curl -L -s http://${REGISTRY_SERVER}:8080/ocp4_downloads --list-only
```

Output should be:
```
<html>
<head><title>Index of /ocp4_downloads/</title></head>
<body>
<h1>Index of /ocp4_downloads/</h1><hr><pre><a href="../">../</a>
<a href="clients/">clients/</a>                                           24-May-2020 10:10                   -
<a href="dependencies/">dependencies/</a>                                      24-May-2020 10:11                   -
<a href="ocp4_downloads/">ocp4_downloads/</a>                                    24-May-2020 11:58                   -
<a href="ocp4_install/">ocp4_install/</a>                                      24-May-2020 11:55                   -
<a href="registry/">registry/</a>                                          24-May-2020 10:10                   -
</pre><hr></body>
</html>
```

## Continue with disconnected (air-gapped) installation of OpenShift
When preparing the bastion node for a disconnected installation, use the [vmware-ocp43-airgapped-example.inv](/inventory/vmware-ocp43-airgapped-example.inv) as an example.