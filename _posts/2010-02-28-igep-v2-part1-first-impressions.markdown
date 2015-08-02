---
published: false
layout: post
category: IoT
tags: 
  - IoT
  - SheevaPlug
  - IGEP
desc: First impressions with the IGEP-V2 platform
keywords: "IGEPv2, IoT, ARM"
twcardtype: summary_large_image 
twimage: http://dbeck.github.io/images/983/P1010892-large.JPG 
woopra: sheevaplugexp
---

This is the first part of my experiences with the [IGEP-V2 platform](http://www.igep-platform.com/). This is a [Beagleborad](http://beagleboard.org/) clone with some very nice additions. They are both credit card size computers based on the Texas Instruments Omap3 CPUs. It is an ARM family CPU with very low power consumption. Both have nice homepages so I will not repeat specs here. I will rather compare my experiences with my [Sheevaplug](http://www.newit.co.uk/) device that I bought earlier. It is also an ARM family computer based on the Marvell Kirkwood platform.

### About IGEP-V2

One of the reason I chose IGEP is the fact that it is produced by an European firm, so I have better chance for timely delivery and reasonable shipping prices. My original target was Beagleboard, but when I tried to order it was out of stock. With some googling I found IGEP and several other clones. The good thing is that IGEP has more memory, ethernet connector and it can optionally have bluetooth and Wifi.

### Delivery

After I made my order on the ISEE (the supplier) site I received a confirmation that they really received my order. Then my order stayed in ‘processing’ state for two wheeks, whatever that really means. Then I lost my patience and sent an email asking what this ‘processing’ state means and what implications it has for the delivery date. Very shortly I received an email apologizing and then they sent the goods by Fedex on the next day. The Fedex shipping was fast.

### The goods I ordered

I ordered the IGEP V2 version without the Bluetooth and Wifi. I also bought the enclosure and a DB9 debug cable. I bought the 5v power adapter in Hungary. I also needed some additional things like a HDMI-DVI cable and a MicroSD card. This is how IGEP looks like:

![](/images/977/P1010891-large.JPG)
![](/images/1001/P1010898-large.JPG)

I placed a few things near the IGEP device for comparison.

### Using the device

When I connected everything and powered the device it did start pretty well. It booted a Poky Linux and showed this screen:

![](/images/1007/P1010906-large.JPG)

The screen shows all GUI applications installed. A bit of everything, but apart from the terminal nothing really usable. The best part is that it only consumes 94MB from the 512MB flash. The same applies for the text based applications. Most of the common Linux tools are the busybox version. So the fdisk utility has no expert menu and all other tools are dumber than the original one. This caused me quite some headache when I wanted to upgrade the factory Linux. The conclusion is that is not doable with the device alone. I guess if I have ordered the micro SD card ISEE sells on the website this could have been a lot easier, but now I’m on my own to solve this.

### Screen resolution issue

I connected the IGEP to an HP 15 inch LCD (L1520) that has DVI input. The graphics seem to be a bit blur so I checked the resolution it uses to drive the monitor. It was (1008×760) which is 16×8 pixels narrower than the native resolution. The monitor can handle that but it is not as sharp as the native resolution.

### Keyboard issue

The factory Linux distribution has a problem with the keyboard handling. I have not figured out so far how to solve this. Certain keys like the arrow, home, end, pgup, pgdown does not work under X.

### The serial debug cable

I bought a DB9 serial cable from ISEE to debug the IGEP device. The funny thing is that the connector on the board is too close to the USB connector so I had to cut a bit from the serial connector to actually be usable. The next thing is that the cable has a male connector on the DB9 side so I needed a NULL modem cable to connect it to a USB-Serial cable.

### Comparison with Sheevaplug

This is not fair in many sense. Sheevaplug has no display controller, so one must use an USB based display adapter. I bought an Arkview device and with reasonable effort I made it working pretty well. However it has some USB issues so it is not very usable as a desktop device. The main promise of IGEP for me was that it has a display controller. The Poky Linux issues so far have prevented me from using IGEP as a desktop machine.

The user community and support so far looks a lot better for Sheevaplug. I found the solution easily to all the problems I bumped into.

The factory supplied software on the Sheevaplug is also better. It is a Ubuntu linux with all the usual tools. It has an apt package manager so all the software I missed could be installed like a breeze. The most needed part left out from the IGEP factory software is GCC. If thay had installed that the life would have been a lot easier.

### What next

I have lots of things to be solved for IGEP. I need a decent linux distro to make it usable. I hope the keyboard issue will be solved by a different distro. To use the distro I have two options:

1. create a bootable Micro SD card
2. boot from TFTP and NFS

I have not decided yet which path I take, but I keep you posted.

## More IGEP Pictures

![](/images/983/P1010892-large.JPG)
![](/images/989/P1010895-large.JPG)
![](/images/995/P1010896-large.JPG)

## IGEP and Sheevaplug together

![](/images/1013/P1010908-large.JPG)

