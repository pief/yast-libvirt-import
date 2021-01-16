#!/bin/bash

set -e

ISO=~/Work/ISOs/openSUSE-Leap-15.2-DVD-x86_64.iso

function cleanup() {
    [ -d /tmp/dud ] && rm -r /tmp/dud
    [ -f libvirt-import-dud.tar.gz ] && rm libvirt-import-dud.tar.gz
    [[ "$(LANG=C virsh -c qemu:///system domstate yasttest 2>&1)" == "running" ]] &&  virsh -c qemu:///system destroy yasttest >/dev/null
    virsh -c qemu:///system dominfo yasttest >/dev/null 2>&1 && virsh -c qemu:///system undefine --nvram yasttest >/dev/null
}
trap cleanup EXIT

mkdir -p /tmp/dud/y2update/
(cd ../src && find * -name *.rb -exec cp --parents {} /tmp/dud/y2update/ \;)
cp ../src/update.pre /tmp/dud/
mkdud --create libvirt-import-dud.tar.gz --name yast-libvirt-import --dist leap15.2 --format tar.gz /tmp/dud/y2update /tmp/dud/update.pre
rm -r /tmp/dud

sudo qemu-img snapshot yasttest.qcow2 -a pre_test
virt-install --connect qemu:///system \
             --name yasttest \
             --memory 2048 \
             --vcpus 1 \
             --location $ISO \
             --disk yasttest.qcow2 \
             --boot uefi \
             --initrd-inject libvirt-import-dud.tar.gz \
             --initrd-inject autoinst.xml \
             -x "dud=file:/libvirt-import-dud.tar.gz"
