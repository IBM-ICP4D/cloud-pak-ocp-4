# Explanation of what happens during preparation of the OpenShift installation
The script runs the `playbooks/ocp4.yaml` Ansible playbook which will do the following:
* Disable firewall on the Bastion node
* Create installation directory (default is `/ocp_install`, configurable in the inventory file)
* Configure proxy client (if applicable)
* Install packages on the Bastion node (nginx, dnsmasq, ...)
* Set up chrony NTP server on the Bastion node, this will be used by all OpenShift nodes to sync the time
* Generate `/etc/ansible/hosts` file, useful to run `ansible` scripts later
* Download OpenShift client and dependencies (Red Hat CoreOS)
* Configure passwordless SSH on the Bastion node
* Generate OpenShift installation configuration (`install-config.yaml`)
* Generate installation scripts used in subsquent steps
* Set up DNS and DHCP server on the Bastion node (needed for OpenShift installation)
* Generate CoreOS ignition files which will used when the OpenShift nodes are booted with PXE
* Create PXE files based on the MAC addresses of the OpenShift nodes
* Set up a load balancer (`haproxy`) on the Bastion node
* Configure NFS on the bastion node
