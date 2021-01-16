This directory's `test.sh` script helps you with testing the yast-libvirt-import module with a openSUSE Leap 15.2 Network installation in a virtual machine.

It needs:
1. a working libvirt setup, i.e. `virt-install` should work.
2. the openSUSE Leap 15.2 NET install iso available from [the openSUSE website](https://software.opensuse.org/distributions/leap). Correct the path in the `ISO=` line accordingly.
3. a `yasttest.qcow2` image (see below).
4. [mkdud](https://github.com/openSUSE/mkdud) (`zypper install mkdud`)

### The yasttest.qcow2 disk image

You need to create this disk image yourself with `qemu-img`. 

Initially this can be an empty image, in this case comment out the `trap cleanup EXIT` and `qemu-img snapshot` lines in `test.sh` and the libvirt import module simply won't find any existing libvirt configurations on the disk. Then do an ordinary installation and afterwards create some files beneath `/etc/libvirt/storage`, `/etc/libvirt/qemu/` and `/etc/libvirt/qemu/networks` manually and also set up some symlinks in `autostart` subdirectories like libvirt would do. For the purposes of testing this module their contents won't really matter.

Next shutdown the VM. As the `cleanup` function has not run, you now have a `yasttest.qcow2` image suitable for testing the module. You should now create a snapshot with `qemu-img snapshot -a pre_test`.

If you now undo the commenting of the two lines in the `test.sh` script, you can play around as much as you like with the module and perform installations -- as soon as you close the virt-viewer window the temporary VM will be destroyed and if you rerun `test.sh` all changes since the snapshot will be reverted.

### The Driver Update Disk archive

`test.sh` prepares a Driver Update Disk (DUD) archive (see [Henne Vogelsang's Update-Media-HOWTO](https://ftp.suse.com/pub/people/hvogel/Update-Media-HOWTO/) with [mkdud](https://github.com/openSUSE/mkdud) that includes the source code from `src` and the `update.pre` script. `test.sh` passes the parameters `dud=<location>` that tell linuxrc to apply that DUD archive onto the loaded installation system and `insecure=1` which disables signature verification on the DUD archive.

Because we use a network install and have no network resource we could load the DUD archive from, we let `virt-install` inject it into the initrd, among with an Autoyast control file `autoinst.xml` that automates most of Yast's prompts for easier testing.
