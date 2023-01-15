#!/usr/bin/env bash

if ! type dirname > /dev/null 2>&1; then
    echo "Not even a linux or macOS, Windoze? We don't support it. Abort."
    exit 1
fi

. "$(dirname "$0")"/common.sh

init_with_root_or_sudo "$0"

begin_banner "Top level" "Init bastion machine"

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

        systemctl status firewalld > /dev/null 2>&1 && systemctl stop firewalld && systemctl disable firewalld
        yum -y update
        yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
        yum install -y ansible bind-utils buildah chrony dnsmasq git \
                       haproxy httpd-tools jq libvirt net-tools nfs-utils nginx podman \
                       python3 python3-netaddr python3-passlib python3-pip python3-policycoreutils python3-pyvmomi python3-requests \
                       screen sos syslinux-tftpboot wget yum-utils

        LATEST_PIP=$(find /usr/bin -name 'pip*'|sort|tail -1)
        "$LATEST_PIP" install passlib

	     ;;
      *) ;;
    esac

done_banner "Top level" "Init bastion machine"
