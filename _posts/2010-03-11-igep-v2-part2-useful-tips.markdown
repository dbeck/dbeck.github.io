---
published: false
layout: post
category: IoT
tags:
  - IoT
  - igep
desc: A few useful tips for using the IGEP-V2 device
description: A few useful tips for using the IGEP-V2 device
keywords: "IGEPv2, IoT, ARM, Ubuntu, Poky, Linux"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/977/P1010891-large.JPG
pageid: igep2
---

This is the second episode of my soap-opera with IGEP/V2 . I like this device a lot. I still see the potential to use this as my desktop machine. The first step on the road is to change the factory installed linux to something more usable. The documentation is very bad, so I had to find out lots of things myself. Some of my experiences are collected here.

### ISEE provided VMWare image

The most documented way of interacting with IGEP-V2 is to download the VMWare image from the ISEE site that they call SDK. This is an x86 Ubuntu linux with a set of tools configured to cross compile to IGEP. It also has tools to create UBoot binaries. To download the image one need to fill the free registration form.

To use the VMWare image as described was not very convenient for me, but fortunately I have other Linux devices. One is running x86 Linux. The next task was to figure out what to do with the image without running VMWare.

### Qemu to the rescue

I didn’t really want to run the image in Qemu either, but fortunately there is a conversion tool in the qemu package that is able to convert the VMDK image to a raw image.

```
qemu-img convert -f vmdk "Ubuntu-8.04-IGEP-v2.0-20091222/Ubuntu 8.04 IGEP v2.0.vmdk" -O raw VM.raw
```

This creates a raw image file of the VMWare image. The size of the image is around 4.8GB. The funny thing is that the filesystem says it is 100GB. I created a separate filesystem for this experiment with 9GB size so this is obviously wrong. The df -h command says 4.8GB used which is more reasonable.

### Check where the ext3 partition starts within the raw image

I tried fdisk to see what is in the image:

```
w5 UBUNTU # fdisk VM.raw
You must set cylinders.
You can do this from the extra functions menu.

Command (m for help): u
Changing display/entry units to sectors

Command (m for help): p

Disk VM.raw: 0 MB, 0 bytes
255 heads, 63 sectors/track, 0 cylinders, total 0 sectors
Units = sectors of 1 * 512 = 512 bytes

Device Boot      Start         End      Blocks   Id  System
VM.raw1   *          63   206692289   103346113+  83  Linux
...
```

This told me there is a linux partition starts at sector 63 . This is 63×512=32256 offset in bytes.

### Mount the ext3 filesystem

I presumed it is an ext3 filesystem so I created a loopback device from offset 32256 and mounted it under /mnt/X :

```
losetup -o 32256 /dev/loop0 VM.raw
mount /dev/loop0 /mnt/X
```

Now I have the ext3 filesystem of the provided image mounted under /mnt/X . The best thing to discover the image is to chroot into it by “chroot /mnt/X”. Then we see a familiar Ubuntu installation. We can also install packages with apt. This will be important later…

### Booting the device

The factory default boot order of the UBoot loader on IGEP-V2 is this:

*   try to boot from the MicroSD
*   try to boot from NFS/TFTP
*   boot from flash

At that moment I didn’t have a bootable MicroSD, so I tried the NFS option. The factory default IP of the device is 192.168.254.254 so that has to be enabled in the exports file. The device looks for a TFTP server to load the uImage and an NFS server to mount the root filesystem so both has to be set up. The device connects to 192.168.254.10 so the servers have to listen on that address. It is also important that it uses NFSv2\. My first attempt to use the userspace NFS daemon failed because of that.

The next thing is to copy the /srv directory to the NFS server from the converted image.

```
root@localhost:/# ls srv/*/*
srv/nfs/poky:
  poky-image-demo  poky-image-minimal  poky-image-sato

srv/tftp/poky:
  poky-image-demo  poky-image-minimal  poky-image-sato
```

There are 3 distributions in the image. It boots the poky-image-sato distribution by default. To change that one needs an RS232 debug console cable and set the appropriate variables in UBoot. A much easier option is to rename the directories on the NFS/TFTP server.
