This directory's `test.sh` script helps you with testing the yast-libvirt-import module with a openSUSE Leap 15.2 Network installation in a virtual machine and thereby also demonstrates integration of the source code through the Driver Update Disk mechanism.

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

`test.sh` prepares a Driver Update Disk archive (see [Henne Vogelsang's Update-Media-HOWTO](https://ftp.suse.com/pub/people/hvogel/Update-Media-HOWTO/) with [mkdud](https://github.com/openSUSE/mkdud) that includes the source code from `src` and the script `update.pre`. `test.sh` passes the parameters `dud=<location>` that tell linuxrc to apply that DUD archive onto the loaded installation system and `insecure=1` which disables signature verification on the DUD archive.

Because we use a network install and have no network resource we could load the DUD archive from, we let `virt-install` inject it into the initrd, among with an Autoyast control file `autoinst.xml` that automates most of Yast's prompts for easier testing.

### update.pre

After unpacking the DUD the `update.pre` script gets executed. This is a special name also described in the [Update-Media-HOWTO](https://ftp.suse.com/pub/people/hvogel/Update-Media-HOWTO/). In our case this script is the glue that patches Yast files in the installation system - in a truely ugly but working way, using a wild orgy of shell scripting and `sed` regular expressions. Because we're using an installation system loaded from the network that can change over time, I don't want to simply overwrite files. And I can't use patches because `patch` is not available in the installation system. On the positive side, the regexps used are probably more likely to apply cleanly than a patch...

The files that get patched are:

- `/control.xml`: this is the [product control file](https://github.com/yast/yast-installation/blob/master/doc/control-file.md) that configures the installation workflow and can be found on every installation medium. It may remind of an Autoyast control file, especially since it can also be used to configure things such as the installation language, but it's more intended to customize the installation than to automate it. Product control files also define proposal screens which call out to proposal modules. This is one of the places where we call the `LibvirtImportProposalClient`.
- `lib/installation/clients/inst_pre_install.rb`: this is where Yast examines hard disks for existing Linux installations and tries to save data from it (existing users, SSH keys and configuration). Behind the existing call to `read_ssh_info` we hook a call to a `read_libvirt_info` function which calls our `LibvirtImporter`'s `scan_device` function.
- `lib/installation/clients/copy_files_finish.rb`: this is where Yast copies files into the installed system. Behind the existing call to `copy_ssh_files` we hook a call to a `copy_libvirt_files` function which calls our `LibvirtImporter`'s `write_cfgfiles` function.

In theory we would also patch `clients/inst_autosetup.rb`: when using an automated installation its `InstAutosetupClient` runs at the beginning. It implements its own screen "Preparing System for Automated Installation" where it replaces the otherwise manually made decisions with the choices made in the Autoyast control file. To fully support Autoyast, we would need to implement our own module here as well which we currently don't have. Meaning if you perform an automatic installation *without* confirmation, <tt>libvirt_import</tt> will always import *all* configuration files it finds.

