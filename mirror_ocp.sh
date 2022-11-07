#!/usr/bin/env bash

if ! type dirname > /dev/null 2>&1; then
    echo "Not even a linux or macOS, Windoze? We don't support it. Abort."
    exit 1
fi

. "$(dirname "$0")"/common.sh

init_with_root_or_sudo "$0"

begin_banner "Top level" "create an OCP mirror registry"

    case ${THE_DISTRIBUTION_ID} in
      debian)
        my_exit "debian not supported yet." 222
	     ;;
      ubuntu)
        my_exit "ubuntu not supported yet." 222
	     ;;
      Darwin)
        my_exit "macOS not supported yet." 222
	     ;;
      rhel|centos)
        if [ "X$THE_DISTRIBUTION_VERSION" != "X8" ]; then
          my_exit "only support centos/RHEL 8.x" 126
        fi

	# the pull secret file is needed to go forward
	#if [ -z $pull_secret_file ];then
  	#	pull_secret_file="/tmp/ocp_pullsecret.json"
	#fi

	if [ ! -e "${pull_secret_file-/tmp/ocp_pullsecret.json}" ];then
  		echo "Pull secret file ${pull_secret_file-/tmp/ocp_pullsecret.json} does not exist, please create the file or set the pull_secret_file environment variable to point to the file that holds the pull secret."
  		exit 1
	fi

	# export environment variables for reusing
	export REGISTRY_DOMAIN=chenjfocp.ibm.com
	export REGISTRY_SERVER="registry.${REGISTRY_DOMAIN}"
	export REGISTRY_PORT=5000
	export LOCAL_REGISTRY="${REGISTRY_SERVER}:${REGISTRY_PORT}"
	export EMAIL="admin@${REGISTRY_DOMAIN}"
	export REGISTRY_USER="admin"
	export REGISTRY_PASSWORD="passw0rd"

	export OCP_RELEASE="4.8.52"
	export RHCOS_RELEASE="4.8.14"
	export LOCAL_REPOSITORY='ocp4/openshift4' 
	export PRODUCT_REPO='openshift-release-dev' 
	export MIRROR_DIR='/ocp4_downloads' 
	export LOCAL_SECRET_JSON="${MIRROR_DIR}/ocp4_install/ocp_pullsecret.json"
	export RELEASE_NAME="ocp-release"

	export MIRROR_REGISTRY_HTTP_PORT=8090

	# disable firewall first
	systemctl stop firewalld;systemctl disable firewalld

	# install the dependent tools
	yum -y install wget podman httpd-tools jq nginx

	# add host to /etc/hosts
	PRIV_IP=$(hostname -I|awk '{print $1}')
	grep "${PRIV_IP} ${REGISTRY_SERVER} registry" /etc/hosts > /dev/null || echo "${PRIV_IP} ${REGISTRY_SERVER} registry" >> /etc/hosts

	# make mirror dir
	mkdir -p ${MIRROR_DIR}/{clients,dependencies,ocp4_install}
	mkdir -p ${MIRROR_DIR}/registry/{auth,certs,data,images}

	# download oc client
	wget -c https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.8/openshift-client-linux.tar.gz -O ${MIRROR_DIR}/clients/openshift-client-linux.tar.gz
	wget -c https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.8/openshift-install-linux.tar.gz -O ${MIRROR_DIR}/clients/openshift-install-linux.tar.gz

	# download coreos
	# folowwing is for PXE boot
	#wget -c https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.8/latest/rhcos-${RHCOS_RELEASE}-x86_64-metal.x86_64.raw.gz -O ${MIRROR_DIR}/dependencies/rhcos-${RHCOS_RELEASE}-x86_64-metal.x86_64.raw.gz
	wget -c https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.8/latest/rhcos-${RHCOS_RELEASE}-x86_64-live-kernel-x86_64 -O ${MIRROR_DIR}/dependencies/rhcos-${RHCOS_RELEASE}-x86_64-live-kernel-x86_64
	wget -c https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.8/latest/rhcos-${RHCOS_RELEASE}-x86_64-live-initramfs.x86_64.img -O ${MIRROR_DIR}/dependencies/rhcos-${RHCOS_RELEASE}-x86_64-live-initramfs.x86_64.img
	wget -c https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.8/latest/rhcos-${RHCOS_RELEASE}-x86_64-live-rootfs.x86_64.img -O ${MIRROR_DIR}/dependencies/rhcos-${RHCOS_RELEASE}-x86_64-live-rootfs.x86_64.img
	#wget -c https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.8/latest/rhcos-${RHCOS_RELEASE}-x86_64-live.x86_64.iso -O ${MIRROR_DIR}/dependencies/rhcos-${RHCOS_RELEASE}-x86_64-live.x86_64.iso

	# following is for OVA install
	#wget -c https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.8/latest/rhcos-${RHCOS_RELEASE}-x86_64-vmware.x86_64.ova -O ${MIRROR_DIR}/dependencies/rhcos-${RHCOS_RELEASE}-x86_64-vmware.x86_64.ova

	# extract and install oc into /usr/local/bin
	tar xvzf ${MIRROR_DIR}/clients/openshift-client-linux.tar.gz -C /usr/local/bin

	# generate the self-signed certs for the mirrored registry
	openssl req -newkey rsa:4096 -nodes -sha256 -keyout ${MIRROR_DIR}/registry/certs/registry.key -x509 -days 365 -out ${MIRROR_DIR}/registry/certs/registry.crt -subj "/C=US/ST=/L=/O=/CN=$REGISTRY_SERVER" -addext "subjectAltName = DNS:$REGISTRY_SERVER"

	# generate the auth for the mirrored registry
	htpasswd -bBc ${MIRROR_DIR}/registry/auth/htpasswd $REGISTRY_USER $REGISTRY_PASSWORD

	# pull the registry docker image
	podman pull docker.io/library/registry:2

	# pull the nfs-provider image
	podman pull gcr.io/k8s-staging-sig-storage/nfs-subdir-external-provisioner:v4.0.2

	# run the registry container
	podman run --name mirror-registry --publish $REGISTRY_PORT:5000 \
     		--detach \
     		--volume ${MIRROR_DIR}/registry/data:/var/lib/registry:z \
     		--volume ${MIRROR_DIR}/registry/auth:/auth:z \
     		--volume ${MIRROR_DIR}/registry/certs:/certs:z \
     		--env "REGISTRY_AUTH=htpasswd" \
     		--env "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
     		--env REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
     		--env REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
     		--env REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
     		docker.io/library/registry:2

	# copy the generated self-signed certs of the mirrored registry to the trust store
	/usr/bin/cp -f ${MIRROR_DIR}/registry/certs/registry.crt /etc/pki/ca-trust/source/anchors/
	update-ca-trust

	# list the mirrored registry catalog to verify it's working
	curl -u $REGISTRY_USER:$REGISTRY_PASSWORD https://${LOCAL_REGISTRY}/v2/_catalog

	# generate the pull secret for the mirroed registry
	AUTH=$(echo -n "$REGISTRY_USER:$REGISTRY_PASSWORD" | base64 -w0)

	CUST_REG='{"%s": {"auth":"%s", "email":"%s"}}\n'
	printf "$CUST_REG" "$LOCAL_REGISTRY" "$AUTH" "$EMAIL" > /tmp/local_reg.json

	jq --argjson authinfo "$(</tmp/local_reg.json)" '.auths += $authinfo' "${pull_secret_file-/tmp/ocp_pullsecret.json}" > ${MIRROR_DIR}/ocp4_install/ocp_pullsecret.json

	# now really doing the mirror
	oc adm -a ${LOCAL_SECRET_JSON} release mirror \
     		--from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-x86_64 \
     		--to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
     		--to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}


	# list the mirrored registry catalog again to verify it's working
	curl -u $REGISTRY_USER:$REGISTRY_PASSWORD https://${LOCAL_REGISTRY}/v2/_catalog

	# generate nginx config based on template and variables
	cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.by.mirror.registry
	envsubst < ${SCRIPT_ABS_PATH}/nginx.conf.tpl > /etc/nginx/nginx.conf
	ln -s ${MIRROR_DIR} /usr/share/nginx/html${MIRROR_DIR}
	systemctl restart nginx;systemctl enable nginx

	# check the http list entries
	curl -L -s http://${REGISTRY_SERVER}:${MIRROR_REGISTRY_HTTP_PORT}${MIRROR_DIR} --list-only

	# generate a systemd service the for mirror registry
	#podman generate systemd mirror-registry -n > /etc/systemd/system/container-mirror-registry.service
	#systemctl enable container-mirror-registry.service
	#systemctl daemon-reload



	     ;;
      *) ;;
    esac

done_banner "Top level" "create an OCP mirror registry"

