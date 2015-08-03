---
published: true
layout: post
category: IoT
tags: 
  - IoT
  - HawkBoard
desc: My HawkBoard starts using a SATA disk
keywords: "Hawkboard, IoT, ARM, SATA, Disk"
twcardtype: summary_large_image 
twimage: http://dbeck.github.io/images/1061/P1020013-large.JPG
woopra: hawkboard2
---

In this second part of my Hawkboard tale I share my experiences installing Gentoo Linux on an SD card, how I failed with the SATA disk and how much I appreciated Texas Instruments customer support. Finally I was able to use the SATA disk by choosing the right kernel and patches.

### Big thanks to TI support

In the world of embedded devices I have very bad experiences. Some companies create fancy web pages about their great product but don’t even publish prices. Others keep technical information and only share them under NDA. I must be honest this irritates me. I am a developer and if I invest time to develop on a hardware than the producer will benefit from that. For this reason I evaluated lots of hardware and when my time allows I publish my thoughts ( [IGEP-V2](http://dbeck.beckground.hu/tags/igep) [SheevaPlug](http://dbeck.beckground.hu/tags/sheevaplug) [SmartQ-v7](http://dbeck.beckground.hu/tags/smartq) [Hawkboard](http://dbeck.beckground.hu/tags/sheevaplug) ).

I liked Hawkboard because of its features and its price. It was clear that I have to invest significant amount of time first to evaluate and then to use it. For this reason I was postponing this all the time. At the meantime I read articles about DSP programing and how to get started with the DaVinci platform. Finally I bumped into a TI page about the [OMAP and DaVINCI Software for DUMMIES](http://focus.ti.com/dsp/docs/dspsplash.tsp?contentId=52451) book. First I didn’t like to register and also the fact that I cannot download the book. I forgot this and few weeks later I received the paperback book in my PO box. I’m very happy with this and fell in love.

I hate marketing being the science of pushing down products through my throat. But now I see it can be different. This TI book is on my desk for a few weeks and every time I see it I remember that I like Texas Instruments and helps my choice which device to use.

Apart from my feelings for TI it had practical consequences too. I was about to evaluate a Realtek RTD1073 based device and that will wait. I only need to choose one platform and these events made me think TI is the way to go.

### Hawkboard SATA

With this new power I bought a SATA disk (Samsung 2.5” 250GB HM251J) to play with Hawkboard. The sad thing is that it does not work. I read forum posts about this. And the suggestion was to checkout git kernel and the issue was probably fixed there. Before I did that I tried the uImage\_v3 kernel from the [hawktool site](http://code.google.com/p/hawktool/downloads/list) but this did not help either. I’m receiving these errors:

```
ata1: softreset failed (device not ready)
ata1: link is slow to respond, please be patient (ready=0)
ata1: softreset failed (device not ready)
ata1: link is slow to respond, please be patient (ready=0)
ata1: softreset failed (device not ready)
ata1: limiting SATA link speed to 1.5 Gbps
ata1: softreset failed (device not ready)
ata1: reset failed, giving up
```

This error is a pretty bad news for me. I mounted NFS root to Hawkboard and its performance was about 1MB/s and looked CPU limited. My usual strategy for devices is to create their environment on an NFS share will not be optimal for this device.

## Installing Gentoo

To compile kernel from Git I will need couple of tools, that implies I have to decide which distribution to use. There are couple of available distros. They can be accessed from [this eLinux Hawkboard page](http://elinux.org/Hawkboard) . Now I take the harder path because I don’t want those.

The Gentoo install steps largely follows the way [I installed Gentoo on Igep](http://dbeck.beckground.hu/articles/2010/03/21/igep-v2-part-4/) .

I chose the stage3-armv5tel-20100220.tar.bz2 tarball. Extracted it on an SD card and mounted it. I also mounted proc and dev. Then I chrooted into that environment.

The steps needed:

1.  (on a different computer) mount /dev/mmcblk0p2 /mnt
2.  (on a different computer) cd /mnt
3.  (on a different computer) tar xvfjp /tmp/stage3-armv5tel-20100220.tar.bz2
4.  (on hawkboard) mkdir /mnt
5.  (on hawkboard) mount /dev/mmcblk0p2 /mnt
6.  (on hawkboard) mount -t proc none /mnt/proc
7.  (on hawkboard) mount -t bind -o bind /dev /mnt/dev
8.  (on hawkboard) chroot /mnt

For the rest of these I’ll need networking but that was already set at u-boot. One might also need to set IP address and default gateway.

### Modify make.conf

I modified make.conf and replaced Os flag with O3 which will lead to significantly longer compilation time but faster program execution too.

*   nano /etc/make.conf

```
CFLAGS="-O3 -march=armv5te -pipe " 
CXXFLAGS="-O3 -march=armv5te -pipe " 
CHOST="armv5tel-softfloat-linux-gnueabi" 

FEATURES="buildpkg -ccache -stricter -test strict test-fail-continue assume-digests collision-protect cvs \
         digest distlocks fixpackages multilib-strict news parallel-fetch protect-owned sandbox sfperms sign \
         splitdebug unmerge-logs unmerge-orphans userfetch userpriv usersandbox" 
ACCEPT_KEYWORDS="~arm" 
USE="nls -X -kde -gtk -gnome -fortran -mysql -bluetooth -flac -test -apache2 \
     -kerberos -smartcard linguas_en linguas_en_US linguas_hu"
```

I also set ~arm keyword. buildpkg is set to keep compiled packages. For the initial setup I disabled common use flags that I don’t want for a basic system.

### Basic environment setup

*   env-update
*   emerge —sync
*   emerge —oneshot portage
*   eselect profile list
*   eselect profile set 5

Selected a developer profile. My goal now is to compile a SATA enabled kernel. If this machine will ever run X I can still change the profile and the USE flags in /etc/make.conf

*   nano /etc/locale.gen

```
en_US ISO-8859-1
en_US.UTF-8 UTF-8
hu_HU ISO-8859-2
hu_HU.UTF-8 UTF-8
```

I enabled Hungarian and English locales. Now generate them and also set the timezone:

*   locale-gen
*   cp /usr/share/zoneinfo/CET /etc/localtime

Now I can install useful packages. I usually start with eix which is very helpful addition to portage.

*   emerge eix

This in turn installs:

1.  app-arch/xz-utils-4.999.9_beta

The compilation failed because I forgot to set the time. I set the date and also install ntpdate so I can more easily set it.

*   date —set=’Sat Jul 3 11:59:14 CEST 2010’
*   emerge ntp

This in turn installs:

1.  dev-python/setuptools-0.6.13
2.  dev-perl/TermReadKey-2.30
3.  net-analyzer/net-snmp-5.4.2.1-r4

### Holy crap, this is bloody slow

I am not patient enough. Change strategy. I move what I have compiled to an NFS share and ask my IGEP-V2 and SheevaPlug devices to help compiling. This way I can also make a few things parallel.

### Which kernel to choose

The state of Hawkboard ready kernel is confusing at best. I found [this page](https://patchwork.kernel.org/patch/62204/) that lists a few changes for Hawkboard support but neither the [TI DaVinci git repo](http://git.kernel.org/?p=linux/kernel/git/khilman/linux-davinci.git;a=summary) nor the mainline stable kernel has integrated it.

I found these kernel trees to be considered as a base to be patched:

1.  git://arago-project.org/git/projects/linux-omapl1.git
2.  git://git.kernel.org/pub/scm/linux/kernel/git/khilman/linux-davinci.git
3.  git://arago-project.org/git/projects/linux-davinci.git
4.  linux-2.6.34-gentoo-r1 [the mainline stable, gentoo patched linux kernel]

And these patches:

1.  [Default config for OMAPL138 based hawkboard](https://patchwork.kernel.org/patch/62205/)
2.  [Adds support for OMAPL138 based hawkboard](https://patchwork.kernel.org/patch/62204/)
3.  [Adds audio driver support for OMAPL138 based hawkboard](https://patchwork.kernel.org/patch/62203/)
4.  [VGA monitor support for OMAPL138 based hawkboard](https://patchwork.kernel.org/patch/62206/)
5.  [gitorious / openembedded / angstrom / recipes / linux-davinci / hawkboard_patch-2.6.33rc4-psp-to-hawkboard.patch](http://gitorious.org/angstrom/openembedded/trees/2fe7c801d15b6770e4d1048b58b2e21eb664a0a3/recipes/linux/linux-davinci/hawkboard)

The first four patches are older and a quick look into the codes tells me that the board I have is patched with them. Because I know the SATA support is broken with these I give a try to the last one. I compared the kernels and the most work on da850/DaVinci went into arago/linux-omapl1 tree, so I will patch this one. The patched kernel source [is available here.](http://dbeck.beckground.hu/gentoo/hawkboard-goodies/omapl1-oe-patched-kernel-source.tar.bz2)

Some other files like the [factory kernel config](http://dbeck.beckground.hu/gentoo/hawkboard-goodies/orig-config.txt) and the above mentioned files made [available here.](http://dbeck.beckground.hu/gentoo/hawkboard-goodies/)

#### **UPDATE**

I forked the hawkboard repository on gitorious and applied the patch I used. My git repo can be [accessed here.](http://gitorious.org/~dbeck/hawkboard/dbeck-hawkboard-linux-omapl1)

### Compiling the kernel

First check if u-boot tools are installed:

```
igep src # eix u-boot
[I] dev-embedded/u-boot-tools
     Available versions:  2009.03 (~)2009.06 (~)2009.08 (~)2009.11.1{tbz2}
     Installed versions:  2009.11.1{tbz2}(18:39:06 07/03/10)
     Homepage:            http://www.denx.de/wiki/U-Boot/WebHome
     Description:         utilities for working with Das U-Boot
```

I’m doing the cross compilation from my SheevaPlug chrooted to the NFS environment. The reason is that Sheeva has a fast CPU and the NFS is served from it so it can access the files faster than the others (22 MB/s). Sheeva has an armv5tel CPU so it is binary compatible with the Hawkboard.

```
make ARCH=arm CROSS_COMPILE=armv5tel-softfloat-linux-gnueabi- distclean
make ARCH=arm CROSS_COMPILE=armv5tel-softfloat-linux-gnueabi- da850_omapl138_defconfig
make ARCH=arm CROSS_COMPILE=armv5tel-softfloat-linux-gnueabi- menuconfig
make ARCH=arm CROSS_COMPILE=armv5tel-softfloat-linux-gnueabi- uImage modules modules_install
```

I modified the factory config to include a few things like LVM. It can be [found here.](http://dbeck.beckground.hu/gentoo/hawkboard-goodies/omapl1-oe.config)

The compiled uImage [can be found here](http://dbeck.beckground.hu/gentoo/hawkboard-goodies/uImage_oe-2.6.33-rc4), and the [modules here.](http://dbeck.beckground.hu/gentoo/hawkboard-goodies/modules-oe-2.6.33-rc4.tar.bz2)

The usual disclaimer applies: no warranty, use at your own risk and every file here stay under their original license.

### The new kernel sees my disk!

```
ata1: SATA link up 1.5 Gbps (SStatus 113 SControl 300)
ata1.00: ATA-8: SAMSUNG HM251JI, 2SS00_01, max UDMA/133
ata1.00: 488397168 sectors, multi 0: LBA48 NCQ (depth 31/32), AA
eth0: attached PHY driver [SMSC LAN8710/LAN8720] (mii_bus:phy_addr=1:07, id=7c0f1)
ata1.00: configured for UDMA/133
scsi 0:0:0:0: Direct-Access     ATA      SAMSUNG HM251JI  2SS0 PQ: 0 ANSI: 5
sd 0:0:0:0: [sda] 488397168 512-byte logical blocks: (250 GB/232 GiB)
sd 0:0:0:0: Attached scsi generic sg0 type 0
sd 0:0:0:0: [sda] Write Protect is off
sd 0:0:0:0: [sda] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
 sda: unknown partition table
sd 0:0:0:0: [sda] Attached SCSI disk
```

I’m impressed. The new kernel boots fine and it sees my disk.

### Future

My next task is to setup a proper gentoo system on my HDD. I will keep you posted. I share some quick performance numbers I see on the disk:

```
 # dd if=/dev/zero of=/dev/sda bs=1024k count=1000
 1000+0 records in
 1000+0 records out
 1048576000 bytes (1.0 GB) copied, 39.3837 s, 26.6 MB/s

 # dd if=/dev/sda of=/dev/null bs=1024k count=1000
 1000+0 records in
 1000+0 records out
 1048576000 bytes (1.0 GB) copied, 33.4694 s, 31.3 MB/s
```

The numbers are pretty neat for a small device like this.

### Credits

My task here was to collect the information that was already available. If I used what was already available in the OpenEmbedded project this could work out of the box. I still not plan to use that, but I do respect the work they have put inside. I’m not very surprised to see a few Texas Instruments emails of the contributors. The people I see worked on this, most probably not complete:

*   Khasim Syed Mohammed
*   Koen Kooi
*   Roger Monk

If I omitted anyone please tell me: dbeck-at-beckground-hu. Anyway, thank you guys!

