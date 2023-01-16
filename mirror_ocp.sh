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
        #   pull_secret_file="/tmp/ocp_pullsecret.json"
        #fi

        if [ ! -e "${pull_secret_file-/tmp/ocp_pullsecret.json}" ];then
           echo "Pull secret file ${pull_secret_file-/tmp/ocp_pullsecret.json} does not exist, please create the file or set the pull_secret_file environment variable to point to the file that holds the pull secret."
           echo "You may also want to check the environment variables value within the script before really invoking the script."
           exit 1
        fi

        # export environment variables for reusing
        export MY_REGISTRY_DOMAIN="${REGISTRY_DOMAIN-$domain_name}"
        export MY_REGISTRY_SERVER="${REGISTRY_SERVER-$air_gapped_registry_server}"
        export MY_REGISTRY_PORT=${REGISTRY_PORT-5000}
        export MY_LOCAL_REGISTRY="${LOCAL_REGISTRY-$MY_REGISTRY_SERVER:$MY_REGISTRY_PORT}"
        export MY_EMAIL="${EMAIL-admin@$MY_REGISTRY_DOMAIN}"
        export MY_REGISTRY_USER="${REGISTRY_USER-admin}"
        export MY_REGISTRY_PASSWORD="${REGISTRY_PASSWORD-passw0rd}"

        export MY_OCP_RELEASE_MAIN_VERSION="${OCP_RELEASE_MAIN_VERSION-$openshift_release}"
        export MY_OCP_RELEASE="${OCP_RELEASE-$MY_OCP_RELEASE_MAIN_VERSION.52}"
        export MY_RHCOS_RELEASE="${RHCOS_RELEASE-$MY_OCP_RELEASE_MAIN_VERSION.47}"
        export MY_LOCAL_REPOSITORY="${LOCAL_REPOSITORY-ocp4/openshift4}"
        export MY_PRODUCT_REPO="${PRODUCT_REPO-openshift-release-dev}"
        export MY_MIRROR_DIR="${MIRROR_DIR-$air_gapped_download_dir}"
        export MY_LOCAL_SECRET_JSON="${LOCAL_SECRET_JSON-$MY_MIRROR_DIR/ocp4_install/ocp_pullsecret.json}"
        export MY_RELEASE_NAME="${RELEASE_NAME-ocp-release}"

        export MY_MIRROR_REGISTRY_HTTP_PORT=${MIRROR_REGISTRY_HTTP_PORT-$http_server_port}

        # disable firewall first
        systemctl status firewalld > /dev/null 2>&1 && systemctl stop firewalld && systemctl disable firewalld

        # install the dependent tools
        yum -y install wget podman httpd-tools jq nginx

        # add host to /etc/hosts
        PRIV_IP=$(hostname -I|awk '{print $1}')
        grep "${PRIV_IP} ${MY_REGISTRY_SERVER} registry" /etc/hosts > /dev/null || echo "${PRIV_IP} ${MY_REGISTRY_SERVER} registry" >> /etc/hosts

        # make mirror dir
        mkdir -p "${MY_MIRROR_DIR}"/{clients,dependencies,ocp4_install}
        mkdir -p "${MY_MIRROR_DIR}"/registry/{auth,certs,data,images}

        # download oc client
        wget -c "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-${MY_OCP_RELEASE_MAIN_VERSION}/openshift-client-linux.tar.gz" -O "${MY_MIRROR_DIR}/clients/openshift-client-linux.tar.gz"
        wget -c "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-${MY_OCP_RELEASE_MAIN_VERSION}/openshift-install-linux.tar.gz" -O "${MY_MIRROR_DIR}/clients/openshift-install-linux.tar.gz"

        # download coreos
        # folowwing is for PXE boot
        #wget -c https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${MY_OCP_RELEASE_MAIN_VERSION}/latest/rhcos-${MY_RHCOS_RELEASE}-x86_64-metal.x86_64.raw.gz -O ${MY_MIRROR_DIR}/dependencies/rhcos-${MY_RHCOS_RELEASE}-x86_64-metal.x86_64.raw.gz
        wget -c "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${MY_OCP_RELEASE_MAIN_VERSION}/latest/rhcos-${MY_RHCOS_RELEASE}-x86_64-live-kernel-x86_64" -O "${MY_MIRROR_DIR}/dependencies/rhcos-${MY_RHCOS_RELEASE}-x86_64-live-kernel-x86_64"
        wget -c "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${MY_OCP_RELEASE_MAIN_VERSION}/latest/rhcos-${MY_RHCOS_RELEASE}-x86_64-live-initramfs.x86_64.img" -O "${MY_MIRROR_DIR}/dependencies/rhcos-${MY_RHCOS_RELEASE}-x86_64-live-initramfs.x86_64.img"
        wget -c "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${MY_OCP_RELEASE_MAIN_VERSION}/latest/rhcos-${MY_RHCOS_RELEASE}-x86_64-live-rootfs.x86_64.img" -O "${MY_MIRROR_DIR}/dependencies/rhcos-${MY_RHCOS_RELEASE}-x86_64-live-rootfs.x86_64.img"
        # for liveCD installation
        wget -c "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${MY_OCP_RELEASE_MAIN_VERSION}/latest/rhcos-${MY_RHCOS_RELEASE}-x86_64-live.x86_64.iso" -O "${MY_MIRROR_DIR}/dependencies/rhcos-${MY_RHCOS_RELEASE}-x86_64-live.x86_64.iso"

        # following is for OVA install
        # wget -c https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${MY_OCP_RELEASE_MAIN_VERSION}/latest/rhcos-${MY_RHCOS_RELEASE}-x86_64-vmware.x86_64.ova -O ${MY_MIRROR_DIR}/dependencies/rhcos-${MY_RHCOS_RELEASE}-x86_64-vmware.x86_64.ova

        # extract and install oc into /usr/local/bin
        tar xvzf "${MY_MIRROR_DIR}/clients/openshift-client-linux.tar.gz" -C /usr/local/bin

        # generate the self-signed certs for the mirrored registry
        openssl req -newkey rsa:4096 -nodes -sha256 -keyout "${MY_MIRROR_DIR}/registry/certs/registry.key" -x509 -days 3650 -out "${MY_MIRROR_DIR}/registry/certs/registry.crt" -subj "/C=US/ST=/L=/O=/CN=$MY_REGISTRY_SERVER" -addext "subjectAltName = DNS:$MY_REGISTRY_SERVER"

        # generate the auth for the mirrored registry
        htpasswd -bBc "${MY_MIRROR_DIR}/registry/auth/htpasswd" "$MY_REGISTRY_USER" "$MY_REGISTRY_PASSWORD"

        # pull the registry docker image
        podman pull docker.io/library/registry:2

        # pull the nfs-provider image
        # THIS DOES NOT WORK WITHIN CHINA!!!
        # podman pull k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2

        # run the registry container
        EXISTING_MIRROR_CONTAINER=$(podman ps --all --noheading | awk '$NF=="mirror-registry" {print $1}')
        if [ "X${EXISTING_MIRROR_CONTAINER}" != "X" ]; then
            podman rm -f "${EXISTING_MIRROR_CONTAINER}"
        fi
        podman run --name mirror-registry --publish "$MY_REGISTRY_PORT:5000" \
               --detach \
               --volume "${MY_MIRROR_DIR}/registry/data":/var/lib/registry:z \
               --volume "${MY_MIRROR_DIR}/registry/auth":/auth:z \
               --volume "${MY_MIRROR_DIR}/registry/certs":/certs:z \
               --env "REGISTRY_AUTH=htpasswd" \
               --env "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
               --env REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
               --env REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
               --env REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
               docker.io/library/registry:2

        # copy the generated self-signed certs of the mirrored registry to the trust store
        /usr/bin/cp -f "${MY_MIRROR_DIR}/registry/certs/registry.crt" /etc/pki/ca-trust/source/anchors/
        update-ca-trust

        # list the mirrored registry catalog to verify it's working
        curl -u "$MY_REGISTRY_USER:$MY_REGISTRY_PASSWORD" "https://${MY_LOCAL_REGISTRY}/v2/_catalog"

        # generate the pull secret for the mirroed registry
        AUTH=$(echo -n "$MY_REGISTRY_USER:$MY_REGISTRY_PASSWORD" | base64 -w0)

        printf '{"%s": {"auth":"%s", "email":"%s"}}\n' "$MY_LOCAL_REGISTRY" "$AUTH" "$MY_EMAIL" > /tmp/local_reg.json

        jq --argjson authinfo "$(</tmp/local_reg.json)" '.auths += $authinfo' "${pull_secret_file-/tmp/ocp_pullsecret.json}" > "${MY_MIRROR_DIR}/ocp4_install/ocp_pullsecret.json"

        # now really doing the mirror
        oc adm -a "${MY_LOCAL_SECRET_JSON}" release mirror \
               --from="quay.io/${MY_PRODUCT_REPO}/${MY_RELEASE_NAME}:${MY_OCP_RELEASE}-x86_64" \
               --to="${MY_LOCAL_REGISTRY}/${MY_LOCAL_REPOSITORY}" \
               --to-release-image="${MY_LOCAL_REGISTRY}/${MY_LOCAL_REPOSITORY}:${MY_OCP_RELEASE}"


        # list the mirrored registry catalog again to verify it's working
        curl -u "$MY_REGISTRY_USER:$MY_REGISTRY_PASSWORD" "https://${MY_LOCAL_REGISTRY}/v2/_catalog"

        # generate nginx config based on template and variables
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.by.mirror.registry
        envsubst < "${SCRIPT_ABS_PATH}/nginx.conf.tpl" > /etc/nginx/nginx.conf

        # make the dir part of the MIRROR_DIR under the nginx default root dir first
        # so that link succeed
        MY_NGINX_DEFAULT_DOC_ROOT="/usr/share/nginx/html"
        MY_MIRROR_DIR_DIR_PART=$(dirname "$MY_MIRROR_DIR")
        mkdir -p "$MY_NGINX_DEFAULT_DOC_ROOT/$MY_MIRROR_DIR_DIR_PART"
        ln -s "${MY_MIRROR_DIR}" "MY_NGINX_DEFAULT_DOC_ROOT/${MY_MIRROR_DIR}"
        systemctl restart nginx;systemctl enable nginx

        # check the http list entries
        curl -L -s "http://${MY_REGISTRY_SERVER}:${MY_MIRROR_REGISTRY_HTTP_PORT}${MY_MIRROR_DIR}" --list-only

        # generate a systemd service the for mirror registry
        #podman generate systemd mirror-registry -n > /etc/systemd/system/container-mirror-registry.service
        #systemctl enable container-mirror-registry.service
        #systemctl daemon-reload

        ;;
      *) ;;
    esac

done_banner "Top level" "create an OCP mirror registry"

