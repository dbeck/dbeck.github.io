---
published: true
layout: post
category: IoT
tags: 
  - IoT
  - IGEP
desc: Third part of my Igep V2 advanture on Poky and Ubuntu land
keywords: "IGEPv2, IoT, ARM, Poky, Ubuntu, Linux"
twcardtype: summary_large_image 
twimage: http://dbeck.github.io/images/983/P1010892-large.JPG 
woopra: igep2
---

In this article I collect some insights about the factory installed Poky distribution and my experiences installing Ubuntu. Poky has apparent limitations for being used as a desktop Linux. Ubuntu is much closer, but it takes quite some efforts to create a bootable Micro SD card and Install Ubuntu on that. Here I describe how I created a bootable Micro SD card with Ubuntu and how I tried to make the factory supplied Poky install more comfortable.

### Poky Linux

When I first booted my device I was expecting something more usable then the Poky-Sato image I found. The fact is that I didn’t know where to go from there. Apart from the terminal, it was pretty unusable. Even the command line tools were busybox based so they are small and dumb. Fortunately I did have some previous experiences with my HP Ipaq, running Angstrom linux on it. I knew a bit about ipkg package manager and that helped me with opkg (that is the package manager on Poky), a successor of ipkg.

From my sheevaplug experiences I knew I won’t have too much space on the device to experiment, so first I copied the /srv directories from VMware image to my sheevaplug. And shared them on NFS. After I set the IP address and the TFTP, NFS servers were up and running, my device booted from NFS. [More details about this step…](http://dbeck.github.io/igep-v2-part2-useful-tips/)

Then I tried to figure out where to look for opkg package sources. The SDK Manual (downloadable from the support site) gives hints about this. Not all sources work what they say, but some does. This is a good starting point because I could replace some dumb utilities and I could make IGEP more usable. The feeds I used are these:

#### /etc/opkg/arch.conf

```
arch all 1
arch any 6
arch noarch 11
arch arm 16
arch armv4 21
arch armv4t 26
arch armv5te 31
arch armv6 36
arch armv7 41
arch armv7a 46
arch igep0020b 51
src/gz oe http://downloads.myigep.com/dist/poky/stable/ipk
src/gz oe-all http://downloads.myigep.com/dist/poky/stable/ipk/all
```

#### /etc/opkg/armv5te-feed.conf

```
src/gz hu-armv5te http://www.openzaurus.org/download/3.5.4/feed/locale/hu
```

#### /etc/opkg/armv7a-feed.conf

```
src/gz all http://downloads.myigep.com/dist/poky/stable/ipk/armv7a
src/gz angstrom-all http://www.angstrom-distribution.org/feeds/2008/ipk/glibc/armv7a/base
```

After these files set I could install usable packages. The first step is “opkg update”. This downloads the package catalogs. Then we can choose from a lot wider selection of packages. To list what is available we can use “opkg list” and “opkg info”. To install packages use “opkg install”. Opkg does have some command line help, so I suggest to read that.

As you may have already noticed I used package feeds from the angstrom and openzaurus projects. This is because some packages that I needed were not available from myigep.com. As a rule of thumb, I always try to install from myigep.com first.

The start, when I could install usable packages were quite promising, but there remained some issues I couldn’t solve. One was the keyboard. I spent quite some time to solve this, but some keys still didn’t work. The other minor issue is the window manager. I see that the matchbox window manager is very practical on a handheld, but I want my IGEP to be a desktop. The matchbox manager is very dumb for desktop use.

### Installing Ubuntu

When I got pissed off with Poky I started looking for alternatives. One was Ubuntu. I bought an 8GB Micro SD Card to host my Ubuntu installation. The first step is to make it bootable. There are guides to help in that. [I liked this.](http://code.google.com/p/beagleboard/wiki/LinuxBootDiskFormat) The next step is to decide what to put on the Micro SD Card. I tried many guides with very mixed results. The one on the IGEP Wiki is very far from working. The closest is [this](http://elinux.org/BeagleBoardUbuntu) This is a guide about the process of installing Ubuntu on the Beagleboard. That board is similar to IGEP. I first tried the Lucid image, but that did not work. It seems to be compiled for an other Arm architecture.

Fortunately Karmic does work, so I suggest to install the Karmic distribution.

To make Karmic really working I mounted the prepared Micro SD card and chroot-ed into it (from Poky). Since my network was up and running in Poky, I only needed to set /etc/resolv.conf and I could access the network from the chroot-ed Micro SD card. Then I installed all packages I thought I will need with aptitude. This includes X window, galeon, bash, ntpdate etc.

I chose to use the kernel already on the flash, so I had to copy the corresponding modules onto the Micro SD card. Without that it won’t work. I also had to set fstab to mount root from the Micro SD card. It is also important to create the boot.ini file [as described here](http://wiki.myigep.com/trac/wiki/HowToGetTheUbuntuDistribution) It has to be copied onto the DOS partition of the Micro SD card.

When all these done the Ubuntu booted fine. The summary of the required steps:

1.  Create a bootable Micro SD card with a small (few megs) DOS partition and an ext2 partition [as described here.](http://code.google.com/p/beagleboard/wiki/LinuxBootDiskFormat)
2.  Grab the root filesystem tarball of Ubuntu Karmic [from here.](http://elinux.org/BeagleBoardUbuntu)
3.  Extract the tarball to the ext2 partition of the Micro SD card
4.  chroot into the root filesystem on the Micro SD card
5.  setup networking and use apt (or aptitude) to install the Ubuntu packages you need
6.  copy the kernel modules from /lib/modules/ to the Micro SD card
7.  set the root password on the Micro SD card
8.  set /etc/fstab on the Micro SD card
9.  Create a boot.ini file [as described here.](http://wiki.myigep.com/trac/wiki/HowToGetTheUbuntuDistribution)
10.  Copy the boot.ini to the DOS partition

When all these done then you should be able to boot from the card. There is one catch however. The boot order of the board boots the card first if there is a boot.ini file. So if there is something wrong with the installed Ubuntu and you placed the Micro SD card, then it won’t try to boot from NFS or Flash. In that case one need to rename the boot.ini in an other device.

### My ubuntu fstab

```
/dev/mmcblk0p2       /                    ext2       rw,noatime            1  1
proc                 /proc                proc       defaults              0  0
devpts               /dev/pts             devpts     mode=0620,gid=5       0  0
usbdevfs             /proc/bus/usb        usbdevfs   noauto                0  0
tmpfs                /var/volatile        tmpfs      defaults              0  0
tmpfs                /media/ram           tmpfs      defaults              0  0
```

The noatime option on the root filesystem can make a real difference in user experience.

### My ubuntu xorg.conf using the omapfb driver

```
Section "Device" 
  Identifier    "OMAPFB Graphics Controller" 
  Driver        "omapfb" 
  Option        "fb" "/dev/fb0" 
EndSection

Section "Monitor" 
  Identifier    "Generic Monitor" 
  Option        "DPMS" 
EndSection

Section "Screen" 
  Identifier    "Default Screen" 
  Device        "OMAPFB Graphics Controller" 
  Monitor       "Generic Monitor" 
  DefaultDepth  16
EndSection
```

To use this configuration a few packages have to be installed. Apart from the obvious X related packages one need to install **hal** and **xserver-xorg-video-omap3** as well.

### Final notes

Although I have a usable SD card with a good set of Desktop programs the SD card I chose is a class 4 card and the IO operations when waiting for the card blocks the whole system. For that reason I tried to migrate the installed Ubuntu system to an NFS share. It did not work. The systems hangs when booting from NFS. There are known issues about NFS root and Karmic but they are not yet fixed on Arm. Now I have these options:

1.  download the sources and the patches and recompile some of the utilities (like mountall)
2.  look for an other distribution

The second option looks harder but this experience tells me there will be other packages not updated. I also have very good experiences with Gentoo on x86 so I will try that first.


