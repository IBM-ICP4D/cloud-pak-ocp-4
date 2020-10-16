# Explanation of what happens during installation of the control plane

## PXE Boot
All OpenShift cluster nodes (bootstrap, masters, workers) were created as "empty" and don't have an operating system installed, which means they will fail at startup and defer boot to PXE (Preboot eXecution Environment); a boot through the network. Every starting node sends out a DHCP broadcast including its MAC address which is picked up by the `dnsmasq` service which was started in the preparation step (`dnsmasq` has a dual role as DNS and DHCP server). The DHCP server replies to the starting node with a suggested IP address and information how to PXE boot, this information is contained in the `dnsmasq` configuration file that was generated before:

```
dhcp-range=192.168.1.200,192.168.1.250

enable-tftp
tftp-root=/ocp_install/tftpboot
dhcp-boot=pxelinux.0
```

As part of `dnsmasq`, a TFTP (Trivial File Protocol) server is started which serves files in the `/ocp_install/tftpboot` directory and its subdirectories. From this TFTP server, the starting node retrieves the SYSLINUX bootloader file, `pxelinux.0`, which does the initial pre-boot of the server. The PXE server reads its configuration from the file associated with the MAC address of the the booting server.

```
[root@bastion pxelinux.cfg]# ll /ocp_install/tftpboot/pxelinux.cfg
total 44
lrwxrwxrwx. 1 root root  48 Apr 21 09:03 01-00-50-52-54-50-01 -> /ocp_install/tftpboot/pxelinux.cfg/bootstrap
lrwxrwxrwx. 1 root root  47 Apr 21 09:03 01-00-50-52-54-60-01 -> /ocp_install/tftpboot/pxelinux.cfg/master-1
...
-rw-r--r--. 1 root root 138 Apr 21 09:02 default
-rw-r--r--. 1 root root 514 Apr 21 09:02 bootstrap
-rw-r--r--. 1 root root 513 Apr 21 09:02 master-1
...
```

In case the booting server has MAC address `00:50:52:54:60:01` it reads the configuration in file `01-00-50-52-54-60-01`; the colons in the MAC address are replaced by dashes and the file name is prefixed with `01` which stands for Ethernet. To simplify finding the configuration file by mere mortals, the PXE configuration file is a symbolic link which points to a file with the host name of the server. The PXE configuration file looks something like this:

```
[root@bastion pxelinux.cfg]# cat master-1
default menu.c32
# set Timeout 3 Seconds
timeout 30
ontimeout linux
label linux
  menu label ^Install RHEL CoreOS
  menu default
  kernel /images/vmlinuz
  append initrd=/images/initramfs.img nomodeset rd.neednet=1 coreos.inst=yes coreos.inst.install_dev=sda coreos.inst.image_url=http://192.168.1.100:8090/rhcos-metal-bios.raw.gz coreos.inst.ignition_url=http://192.168.1.100:8090/ocp43-master-1.ign nameserver=192.168.1.100 ip=192.168.1.101::192.168.1.1:255.255.255.0:master-1.uk.ibm.com:ens192:none:192.168.1.100
```

This may look a bit cryptic but esssentially the file contains all information PXE needs to load the initial ramdisk `initramfs.img`, which is located in the `images` directory in the TFTP root directory. Initram is a temporary root file system in memory. Also, it holds the URL of the CoreOS Linux kernel: `http://192.168.1.100:8090/rhcos-metal-bios.raw.gz`, which is served by the `nginx` HTTP server that was started on the bastion node in the preparation steps. Finally you will find information about the ignition file that configures CoreOS, the IP address, netmask, host name, interface the booted server will assume and the DNS (nameserver) it configures. The ignition file is also served by the HTTP server on the bastion node.

Ignition is a provisioning utility that was created for CoreOS and is a tool that can partition disks, format partitions, write files and configure users. There are 3 types of ignition files that were created during the preparation steps, by the OpenShift installer: bootstrap, master and worker ignition files. In the preparation steps, these standard files were used to generate node-specific ignition files, such as `ocp43-master-1.ign`, which looks as follows:

```
[root@bastion ocp_install]# cat /ocp_install/ocp43-master-1.ign
{
    "ignition": {
        "config": {
            "append": [
                {
                    "source": "http://192.168.1.100:8090/master.ign",
                    "verification": {}
                }
            ]
        },
        "timeouts": {},
        "version": "2.2.0"
    },
    "networkd": {},
    "passwd": {},
    "storage": {
        "files": [
            {
                "contents": {
                    "source": "data:,master-1"
                },
                "filesystem": "root",
                "mode": 420,
                "path": "/etc/hostname",
                "user": {
                    "name": "root"
                }
            },
            {
                "contents": {
                    "source": "data:text/plain;base64,IyBBbnNpYmxlIG1hbmFnZWQKCiMgU2VydmVycyB0byBiZSB1c2VkIGFzIGEgQ2hyb255L05UUCB0aW1lIHNlcnZlcgpzZXJ2ZXIgMTkyLjE2OC4xLjEwMCBpYnVyc3QKCiMgUmVjb3JkIHRoZSByYXRlIGF0IHdoaWNoIHRoZSBzeXN0ZW0gY2xvY2sgZ2FpbnMvbG9zc2VzIHRpbWUuCmRyaWZ0ZmlsZSAvdmFyL2xpYi9jaHJvbnkvZHJpZnQKCiMgU3luY2hyb25pemUgd2l0aCBsb2NhbCBjbG9jawpsb2NhbCBzdHJhdHVtIDEwCgojIEZvcmNlIHRoZSBjbG9jayB0byBiZSBzdGVwcGVkIGF0IHJlc3RhcnQgb2YgdGhlIHNlcnZpY2UgKGF0IGJvb3QpCiMgaWYgdGhlIHRpbWUgZGlmZmVyZW5jZSBpcyBncmVhdGVyIHRoYW4gMSBzZWNvbmQKaW5pdHN0ZXBzbGV3IDEgMTkyLjE2OC4xLjEwMAoKIyBBbGxvdyB0aGUgc3lzdGVtIGNsb2NrIHRvIGJlIHN0ZXBwZWQgaW4gdGhlIGZpcnN0IHRocmVlIHVwZGF0ZXMKIyBpZiBpdHMgb2Zmc2V0IGlzIGxhcmdlciB0aGFuIDEgc2Vjb25kLgptYWtlc3RlcCAxLjAgMwoKIyBFbmFibGUga2VybmVsIHN5bmNocm9uaXphdGlvbiBvZiB0aGUgcmVhbC10aW1lIGNsb2NrIChSVEMpLgpydGNzeW5jCgojIFNwZWNpZnkgZGlyZWN0b3J5IGZvciBsb2cgZmlsZXMuCmxvZ2RpciAvdmFyL2xvZy9jaHJvbnkK"
                },
                "filesystem": "root",
                "mode": 420,
                "path": "/etc/chrony.conf",
                "user": {
                  "name": "root"
                }
            }
        ]
    },
    "systemd": {}
}
```

Again, the above can be a bit intimidating but essentially it starts with appending the standard ignition file that was created by the OpenShift installer. Then, the hostname of the server is set in `/etc/hostname` and the `chrony` time server is configured in file `/etc/chrony.conf`. Because the `chrony` configuration contains special characters such as new lines, the file contents have been encoded in base-64. When we decode the very long string `IyBBbn....nkK` using `base64 -d`, it looks like this:

```
# Ansible managed

# Servers to be used as a Chrony/NTP time server
server 192.168.1.100 iburst

# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift

# Synchronize with local clock
local stratum 10

# Force the clock to be stepped at restart of the service (at boot)
# if the time difference is greater than 1 second
initstepslew 1 192.168.1.100

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

# Specify directory for log files.
logdir /var/log/chrony
```

## Install the control plane
Once the PXE boot components have been set up, you will start the cluster nodes. The bootstrap node is only needed at initial install and serves a temporary control plane that "bootstraps" the permanent OpenShift control plane consisting of the 3 master nodes and a number of worker nodes, dependent on the base configuration you have chosen.

When you open the web console of any of the virtual servers just started, you will observe that the SYSLINUX boot loader is started, then loading the CoreOS operating system and booting it. When the CoreOS operating system is started on the master nodes, they will start `etcd`, `kubetlet` and the other services required by OpenShift.

Once the bootstrap node is started, you can `ssh` to it: `ssh core@bootstrap` and view the journal control log messages as the master nodes are started. Essentially, you don't need to do this as the `wait_bootstrap.sh` will wait until the control plane has been activated.

Sometimes it's useful to take a look at the journal control logs of bootstrap and masters. Especially when the cluster is behind a firewall and/or proxy server, you might find that images cannot be loaded due to restrictive internet access.