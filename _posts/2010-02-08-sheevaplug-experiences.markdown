---
published: true
layout: post
category: IoT
tags: 
  - IoT
  - sheevaplug
desc: How I started using SheevaPlug as a desktop
description: How I started using SheevaPlug as a desktop
keywords: "SheevaPlug, IoT, ARM"
twcardtype: summary_large_image 
twimage: http://dbeck.github.io/images/1013/P1010908-large.JPG
woopra: sheevaplugexp
---

This article is about my experiences with my sheevaplug device, which is the original v1 model (rev 1.3). Marvell announced its 3.0 successor at CES, January 2010. Its price and availability is still unknown.

### Ordering

First I found sheevaplug on the Marvell site. Marvell pointed to several vendors who can deliver devices based on their Kirkwood platform. Most of them was around 100 US dollars. The first issue was to decide which one should I order. Then I realized that some vendors have ran out of stock and they became famous of long delays for delivery. Others had prohibitively high shipping cost (around 50 US dollars) to Hungary. The company I ordered from was [NewIT](https://www.newit.co.uk/shop/) and I'm happy with that decision. The sheevaplug arrived within a week and in perfect condition. So I suggest anyone in Europe to order from them.

### Display

I planned to use this device as a desktop computer. This is an experiment to see wether a device like this can do the task or not. It has very low power consumption and a fanless design. As I use this for editing text and read web pages then performance is not very important for me. I don't use windows so the fact that it is not able to run M$ software is a non-issue for me. There was still a minor issue though: it has no VGA, DVI whatsoever graphical output.  It has USB port so I decided to use a [DisplayLink based USB-VGA adapter](http://www.displaylink.com/shop/index.php?product=5). The one I chose is this. I read in the openplug.org forum that some people had success with Mimo displays so I hoped I can manage to get mine working.

### The hardware setup of my sheevaplug workstation

* Sheevaplug
* 4 port USB hub
* The Arkview USB display adapter
* HP L1520 15" LCD display
* USB mouse, keyboard
* a 4GB SDHC Card

### First step is reinstall

I suggest to reinstall the sheevaplug device with the installer right after its arrival. The advantage of this is to replace the JFFS2 filesystem with UBIFS on the flash. The difference is very noticeable. With UBIFS I boot and start the X window in 30 secs. With JFFS2 it takes minutes.

### Reinstall kernel

The factory kernel does not recognize the displaylink device. For that it needs a udlfb driver with the appropriate patches. Fortunately prebuilt kernels are available from sheeva.with-linux.com. I installed the 2.6.32.3 kernel by downloading the corresponding README file. Changed its permissions to executable and ran it with the -nandkernel parameter. This updated the kernel.

### Display resolution

The updated kernel did recognize my displaylink device but was unable to detect my monitor reolution. This could be seen in the kernel log: "EDID XRES 0 YRES 0". Then the udlfb had set the resolution to factory default which is 1280x1024. Unfortunately this is too high for my monitor. For this reason I recompiled the kernel with a modified udlfb default setting setting (udlfb.c modified by hand). Then I reported my efforts at openplug forum and birdman was kind enough to modifiy the udlfb.c to make the resolution modprobe settable. Full story and downloadables [can be found here](http://plugcomputer.org/plugforum/index.php?topic=343.30).

### Running X window

There are a few issues to be treated here. The first is storage space. I decided to use the internal flash as the root file system, because I measured its performance and it can read/write around 50 MB/sec. My SD card only do 6 MB/sec. So my strategy was to very carefully install X related packages and when my root filesystem was about to be full, I moved larger not very frequently needed files to a directory on my SD card and created symlinks to them. This includes complete directories from /usr/share and also /usr/lib. I carefully choose which directories and files to move. If files like libc is moved than the system may not boot.
A more convenient strategy would be to buy a lot faster SD card and during the installation step at the beginnig, one should choose an SD card based root filesystem instead. This would spare lots of headaches but may sacrifice money and speed. In this case I would create a large swap file on the UBIFS filesystem.
The next step is to download the compiled displaylink driver provided by [mitsus at the forum](http://plugcomputer.org/plugforum/index.php?topic=343.30). Sample xorg.conf file and instructions are also available.

### The xrandr bug

There is one last catch. The displaylink driver for X has a bug. My favourite window manager is xfce4. After installing I realized that it has problems. Right clicking did not display the expected floating menus and also I missed the panel at the bottom. I tried different window managers. Fluxbox was a lot better but after using it for a while it started to behave very strange. Applications did not display menu items and other odd things happened. I spent lots of time googling and I was lucky enough to find the solution. I placed the following into my .fluxbox/startup:

```
XRANDR=`which xrandr`
if [ "x$XRANDR" != "x" ] ; then
  $XRANDR -o 0
  fi
```

After X startup the "xrandr -o 0" command must be run. This fixes the various oddities. Then I was able to run my xfce4 and happy with that.

### Final thoughts

Although I am very happy with my sheevaplug device it must be noted that it is not very fast. I can edit texts and can browse the web and it is usable. The practical consequence of this is that I have to very carefully select what applications I want to use. I use midori browser rather than firefox. I use gnumeric and abiword rather then openoffice. I use kate rather than kdevelop. Video playback is simply unusable in this setup.
After googling a lot I found a faster device that I want to evaluate next: [IGEP v2](http://www.igep-platform.com/). This is a lot faster than sheevaplug, thanks to the floating point and DSP capabilities. This is based on OMAP 3530 like [beagleboard](http://beagleboard.org/) with the addition of RJ45 ethernet, WIFI and Bluetooth. The [IGEP V2](http://www.igep-platform.com/) can be ordered from Europe so the shipping cost is reasonable. Plus ISEE also sells enclosure and other goodies with the device.

