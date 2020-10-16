# Wipe the nodes of the OpenShift cluster

This document describes to prepare VMs that already have an operating system. All VMs, except for the Bastion node, are wiped and installed from scratch by erasing the disk with `dd`. The wiped VM will - on next reboot - start a PXE boot that in turn will start the OpenShift installation with an installation method that is also used for bare metal installations.

## Check if the nodes can be accessed
```
ansible bootstrap,masters,workers -u core -b -a 'bash -c "hostname;whoami"'
```

>**IMPORTANT: BE VERY CAREFUL WITH THE NEXT COMMANDS, THEY CAN DESTROY YOUR CLUSTER**

## Wiping the nodes if OCP 4.x has already been installed
```
ansible bootstrap,masters,workers -u core -b -a 'bash -c "hostname;sudo dd if=/dev/zero of=/dev/sda count=1000 bs=1M;sudo shutdown -h 1"'
```

## Clean known hosts
For the next installation of OpenShift to work ok, remove the known hosts.
```
rm -f ~/.ssh/known_hosts
```