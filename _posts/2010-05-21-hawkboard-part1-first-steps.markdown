---
published: false
layout: post
category: IoT
tags:
  - IoT
  - hawkboard
desc: Getting started using my HawkBoard
description: Getting started using my HawkBoard
keywords: "Hawkboard, IoT, ARM"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/1097/P1020019-large.JPG
woopra: hawkboard1
---

With all my experiences with [IGEP](http://dbeck.beckground.hu/tags/igep) and [SheevaPlug](http://dbeck.beckground.hu/tags/sheevaplug) I was ready for a new experience with an ARM board having a SATA connector. My desktop environment at home is totally ARM based. First I tried SheevaPlug being my desktop but I was not completely satisfied because of the instability of the USB based display. Then I tried IGEP which has proper display handling but when it does I/O on USB or SDHC it largely blocks the system. Finally I set up SheevaPlug to be my NFS server and I use IGEP from NFS root. I compiled a Gentoo system on the IGEP and this became a pretty usable system with acceptable performance. The story was almost done, but there was one point I couldn’t digest: the NFS perfromance. I connected a USB disk to SheevaPlug and it sees around 16MB/s. When it is exported to IGEP through NFS it goes down to 4MB/s. There are also issues with the USB disks power saving. These are the factors that made me curious about the [Hawkboard](http://www.hawkboard.org/) .

### About Hawkboard

Hawkboard is a similar board to IGEP or Beagleboard. Hawkboard has slower CPU, VGA connector instead of HDMI, less memory and smaller flash. The reason I’m interested in the board is the SATA connector, the mixed floating point and fixed point DSP and the lot cheaper price. I know this amount of memory and the slow CPU seriously limits its usability if the DSP’s capabilities are not used. I’m curious how far can we go with them.

### Ordering and shipping

The hawkboard arrived to Hungary within 3 weeks from order. This is not bad given that I wanted this to be shipped with USPS. [Special Computing](https://specialcomp.com/hawkboard/index.htm) preferred UPS or Fedex over USPS, but I knew that the price advantage Hawkboard has could disappear if I use those companies. I ordered two Hawkboards and they were shipped to Hungary for 15 USD, which is not bad. This could have been 50 USD or more with the other companies.

### Unpacking

I forget to set the white balance when I made these photos. I keep them for reference. I ordered a transparent plastic case for the hawkboard. It arrived in a brownish protective wrap.

[![](/images/1061/P1020013-icon.JPG)](/images/1061/P1020013-large.JPG "Hawkboard") [![](/images/1079/P1020016-icon.JPG)](/images/1079/P1020016-large.JPG "Hawkboard") [![](/images/1067/P1020014-icon.JPG)](/images/1067/P1020014-large.JPG "Hawkboard") [![](/images/1049/P1020011-icon.JPG)](/images/1049/P1020011-large.JPG "Hawkboard")[![](/images/1037/P1020009-icon.JPG)](/images/1037/P1020009-large.JPG "Hawkboard")[![](/images/1055/P1020012-icon.JPG)](/images/1055/P1020012-large.JPG "Hawkboard")[![](/images/1073/P1020015-icon.JPG)](/images/1073/P1020015-large.JPG "Hawkboard")[![](/images/1085/P1020017-icon.JPG)](/images/1085/P1020017-large.JPG "Hawkboard")[![](/images/1043/P1020010-icon.JPG)](/images/1043/P1020010-large.JPG "Hawkboard")

I only realized the white balance was wrong after removed the protective wrap from the case…

[![](/images/1109/P1020021-icon.JPG)](/images/1109/P1020021-large.JPG "Hawkboard")[![](/images/1115/P1020022-icon.JPG)](/images/1115/P1020022-large.JPG "Hawkboard")[![](/images/1091/P1020018-icon.JPG)](/images/1091/P1020018-large.JPG "Hawkboard")[![](/images/1097/P1020019-icon.JPG)](/images/1097/P1020019-large.JPG "Hawkboard")[![](/images/1103/P1020020-icon.JPG)](/images/1103/P1020020-large.JPG "Hawkboard")

The transparent plastic case is pretty fragile. It needs practice not to brake it. I actually did…

### First boot

Here are some pictures about the hawkboard boot:

[![](/images/1121/P1020023-icon.JPG)](/images/1121/P1020023-large.JPG "Hawkboard")[![](/images/1127/P1020026-icon.JPG)](/images/1127/P1020026-large.JPG "Hawkboard")[![](/images/1133/P1020027-icon.JPG)](/images/1133/P1020027-large.JPG "Hawkboard")[![](/images/1139/P1020029-icon.JPG)](/images/1139/P1020029-large.JPG "Hawkboard")[![](/images/1145/P1020030-icon.JPG)](/images/1145/P1020030-large.JPG "Hawkboard")[![](/images/1151/P1020035-icon.JPG)](/images/1151/P1020035-large.JPG "Hawkboard")

First it displays the hawk picture and then some linux pingu split into parts because of the resolution mismatch. Then I connected a null modem cable to see if I can get anything from the serial console. It works and one can log into the hawkboard by pressing enter. I made a few pictures about the serial messages too. I also copied come of those messages below.

### U-Boot

U-Boot shows this and pressing spaces lets me in:

* * *

```
U-Boot 2009.01 (Dec 22 2009 - 10:04:02)

DRAM:  128 MB
NAND:  NAND device: Manufacturer ID: 0x2c, Chip ID: 0xa1 (Micron NAND 128MiB 1,8V 8-bit)
Bad block table found at page 65472, version 0x01
Bad block table found at page 65408, version 0x01
nand_read_bbt: Bad block at 0x04fa0000
nand_read_bbt: Bad block at 0x069e0000
nand_read_bbt: Bad block at 0x07100000
128 MiB
*** Warning - bad CRC or NAND, using default environment

In:    serial
Out:   serial
Err:   serial
ARM Clock : 300000000 Hz
DDR Clock : 150000000 Hz
Ethernet PHY: GENERIC @ 0x07
Hit any key to stop autoboot:  0
hawkboard.org >
```

* * *

The U-Boot environment is pretty simple:

* * *

```
hawkboard.org > printenv
bootargs=mem=128M console=ttyS2,115200n8 root=/dev/ram0 rw initrd=0xc1180000,8M
bootcmd=nand read.e 0xc1180000 0x400000 0x800000;nand read.e 0xc0700000 0x200000 0x200000;bootm 0xc0700000
bootdelay=3
baudrate=115200
bootfile="uImage"
stdin=serial
stdout=serial
stderr=serial
ethaddr=0a:c1:a8:12:fa:c0
ver=U-Boot 2009.01 (Dec 22 2009 - 10:04:02)

Environment size: 344/131068 bytes
hawkboard.org >
```

* * *

I need to implement some conditional codes to make it boot from TFTP/NFS and SD Card, just like my IGEP device.

### Kernel messages

dmesg output was this:

* * *

```
Linux version 2.6.32-rc6 (root@vpn) (gcc version 4.3.3 (Sourcery G++ Lite 2009q1-203) ) #1 PREEMPT Mon Dec 21 18:43:58 IST 2009
CPU: ARM926EJ-S [41069265] revision 5 (ARMv5TEJ), cr=00053177
CPU: VIVT data cache, VIVT instruction cache
Machine: OMAPL 138 Hawkboard.org
Memory policy: ECC disabled, Data cache writeback
On node 0 totalpages: 32768
free_area_init_node: node 0, pgdat c03e9564, node_mem_map c040c000
  DMA zone: 256 pages used for memmap
  DMA zone: 0 pages reserved
  DMA zone: 32512 pages, LIFO batch:7
DaVinci da850/omap-l138 variant 0x0
Built 1 zonelists in Zone order, mobility grouping on.  Total pages: 32512
Kernel command line: mem=128M console=ttyS2,115200n8 root=/dev/ram0 rw initrd=0xc1180000,8M
PID hash table entries: 512 (order: -1, 2048 bytes)
Dentry cache hash table entries: 16384 (order: 4, 65536 bytes)
Inode-cache hash table entries: 8192 (order: 3, 32768 bytes)
Memory: 128MB = 128MB total
Memory: 117460KB available (3684K code, 272K data, 148K init, 0K highmem)
SLUB: Genslabs=11, HWalign=32, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
Hierarchical RCU implementation.
NR_IRQS:245
Console: colour dummy device 80x30
Calibrating delay loop... 149.50 BogoMIPS (lpj=747520)
Mount-cache hash table entries: 512
CPU: Testing write buffer coherency: ok
DaVinci: 144 gpio irqs
regulator: core version 0.5
NET: Registered protocol family 16
bio: create slab <bio-0> at 0
SCSI subsystem initialized
libata version 3.00 loaded.
usbcore: registered new interface driver usbfs
usbcore: registered new interface driver hub
usbcore: registered new device driver usb
Switching to clocksource timer0_1
musb_hdrc: version 6.0, cppi4.1-dma, (host+peripheral), debug=0
Waiting for USB PHY clock good...
DA830 OTG revision 4ea11003, PHY 20972, control 00
musb_hdrc: ConfigData=0x06 (UTMI-8, dyn FIFOs, SoftConn)
musb_hdrc: MHDRC RTL version 1.800
musb_hdrc: setup fifo_mode 2
musb_hdrc: 8/9 max ep, 3904/4096 memory
musb_hdrc: hw_ep 0shared, max 64
musb_hdrc: hw_ep 1tx, max 512
musb_hdrc: hw_ep 1rx, max 512
musb_hdrc: hw_ep 2tx, max 512
musb_hdrc: hw_ep 2rx, max 1024
musb_hdrc: hw_ep 3tx, max 512
musb_hdrc: hw_ep 3rx, max 512
musb_hdrc: hw_ep 4shared, max 256
musb_hdrc: USB OTG mode controller at fee00000 using DMA, IRQ 58
musb_hdrc musb_hdrc: MUSB HDRC host driver
musb_hdrc musb_hdrc: new USB bus registered, assigned bus number 1
usb usb1: configuration #1 chosen from 1 choice
hub 1-0:1.0: USB hub found
hub 1-0:1.0: 1 port detected
Registered /proc/driver/musb_hdrc
NET: Registered protocol family 2
IP route cache hash table entries: 1024 (order: 0, 4096 bytes)
TCP established hash table entries: 4096 (order: 3, 32768 bytes)
TCP bind hash table entries: 4096 (order: 2, 16384 bytes)
TCP: Hash tables configured (established 4096 bind 4096)
TCP reno registered
NET: Registered protocol family 1
RPC: Registered udp transport module.
RPC: Registered tcp transport module.
RPC: Registered tcp NFSv4.1 backchannel transport module.
Trying to unpack rootfs image as initramfs...
rootfs image is not initramfs (junk in compressed archive); looks like an initrd
Freeing initrd memory: 8192K
JFFS2 version 2.2. (NAND) ÂŠ 2001-2006 Red Hat, Inc.
msgmni has been set to 245
io scheduler noop registered
io scheduler anticipatory registered (default)
da8xx_lcdc da8xx_lcdc.0: GLCD: Found VGA_Monitor panel
Console: switching to colour frame buffer device 80x30
Serial: 8250/16550 driver, 3 ports, IRQ sharing disabled
serial8250.0: ttyS0 at MMIO 0x1c42000 (irq = 25) is a 16550A
serial8250.0: ttyS1 at MMIO 0x1d0c000 (irq = 53) is a 16550A
serial8250.0: ttyS2 at MMIO 0x1d0d000 (irq = 61) is a 16550A
console [ttyS2] enabled
brd: module loaded
ahci ahci: version 3.0
ahci ahci: forcing PORTS_IMPL to 0x1
ahci ahci: AHCI 0001.0100 32 slots 1 ports 3 Gbps 0x1 impl SATA mode
ahci ahci: flags: ncq sntf pm led clo only pmp pio slum part ccc
scsi0 : ahci
ata1: SATA max UDMA/133 irq 67
NAND device: Manufacturer ID: 0x2c, Chip ID: 0xa1 (Micron NAND 128MiB 1,8V 8-bit)
Bad block table not found for chip 0
Bad block table not found for chip 0
Scanning device for bad blocks
Bad eraseblock 637 at 0x000004fa0000
Bad eraseblock 847 at 0x0000069e0000
Bad eraseblock 904 at 0x000007100000
Bad block table written to 0x000007fe0000, version 0x01
Bad block table written to 0x000007fc0000, version 0x01
Creating 5 MTD partitions on "davinci_nand.1":
0x000000000000-0x000000020000 : "u-boot env"
0x000000020000-0x000000040000 : "UBL"
0x000000040000-0x0000000c0000 : "u-boot"
0x000000200000-0x000000400000 : "kernel"
0x000000400000-0x000008000000 : "filesystem"
davinci_nand davinci_nand.1: controller rev. 2.5
console [netcon0] enabled
netconsole: network logging started
ohci_hcd: USB 1.1 'Open' Host Controller (OHCI) Driver
ohci ohci.0: DA8xx OHCI
ohci ohci.0: new USB bus registered, assigned bus number 2
ohci ohci.0: irq 59, io mem 0x01e25000
usb usb2: configuration #1 chosen from 1 choice
hub 2-0:1.0: USB hub found
hub 2-0:1.0: 1 port detected
Initializing USB Mass Storage driver...
usbcore: registered new interface driver usb-storage
USB Mass Storage support registered.
g_ether gadget: using random self ethernet address
g_ether gadget: using random host ethernet address
usb0: MAC 8e:7b:1a:59:9a:7e
usb0: HOST MAC 92:02:63:9b:05:4d
g_ether gadget: Ethernet Gadget, version: Memorial Day 2008
g_ether gadget: g_ether ready
mice: PS/2 mouse device common for all mice
i2c /dev entries driver
watchdog watchdog: heartbeat 60 sec
cpuidle: using governor ladder
cpuidle: using governor menu
davinci_mmc davinci_mmc.0: Using DMA, 4-bit mode
usbcore: registered new interface driver usbhid
usbhid: v2.6:USB HID core driver
Advanced Linux Sound Architecture Driver Version 1.0.21.
No device for DAI tlv320aic3x
asoc: tlv320aic3x <-> davinci-i2s mapping ok
ALSA device list:
  #0: DA850/OMAP-L138 EVM (tlv320aic3x)
TCP cubic registered
NET: Registered protocol family 17
Clocks: disable unused emac
Clocks: disable unused spi1
davinci_emac_probe: using random MAC addr: 32:fe:6d:3c:de:09
emac-mii: probed
ata1: SATA link down (SStatus 0 SControl 300)
RAMDISK: ext2 filesystem found at block 0
RAMDISK: Loading 8192KiB [1 disk] into ram disk... /
usb 2-1: new full speed USB device using ohci and address 2
\
usb 2-1: not running at top speed; connect to a high speed hub
|
usb 2-1: configuration #1 chosen from 1 choice
/
hub 2-1:1.0: USB hub found
|
hub 2-1:1.0: 4 ports detected
/
usb 2-1.1: new low speed USB device using ohci and address 3
/
usb 2-1.1: configuration #1 chosen from 1 choice
done.
input: CHICONY HP Basic USB Keyboard as /devices/platform/ohci.0/usb2/2-1/2-1.1/2-1.1:1.0/input/input0
generic-usb 0003:03F0:0024.0001: input: USB HID v1.10 Keyboard [CHICONY HP Basic USB Keyboard] on usb-ohci.0-1.1/input0
usb 2-1.2: new low speed USB device using ohci and address 4
usb 2-1.2: configuration #1 chosen from 1 choice
VFS: Mounted root (ext2 filesystem) on device 1:0.
Freeing init memory: 148K
input: Hewlett-Packard  HP f2100a Optical USB Travel Mouse as /devices/platform/ohci.0/usb2/2-1/2-1.2/2-1.2:1.0/input/input1
generic-usb 0003:03F0:2003.0002: input: USB HID v1.00 Mouse [Hewlett-Packard  HP f2100a Optical USB Travel Mouse] on usb-ohci.0-1.2/input0
eth0: attached PHY driver [Generic PHY] (mii_bus:phy_addr=1:07, id=7c0f1)
PHY: 1:07 - Link is Up - 100/Full
```

* * *

It is pretty fresh kernel compiled with Code Sourcery G++ Lite.

### Logged in

When it boots it does not need a password to log in, only an Enter.

* * *

```
Please press Enter to activate this console. PHY: 1:07 - Link is Up - 100/Full

Jan  1 00:00:46 HawkBoard daemon.info init: starting pid 471, tty '': '-/bin/sh'

    Setting shell environment ...
    - Path
    - Aliases

    Done!

[@HawkBoard /]#
```

* * *

That’s it I’m in…

### df

Df shows that very little of the NAND flash is used for the OS.

* * *

```
[@HawkBoard /]# df
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/root                 7931      7608       323  96% /
mdev                     62976         0     62976   0% /dev
none                     62976         0     62976   0% /tmp
[@HawkBoard /]#
```

* * *

Need to figure out where is the rest of the NAND flash…

### cpu info

* * *

```
[@HawkBoard /]# cat /proc/cpuinfo
Processor       : ARM926EJ-S rev 5 (v5l)
BogoMIPS        : 149.50
Features        : swp half thumb fastmult edsp java
CPU implementer : 0x41
CPU architecture: 5TEJ
CPU variant     : 0x0
CPU part        : 0x926
CPU revision    : 5

Hardware        : OMAPL 138 Hawkboard.org
Revision        : 0000
Serial          : 0000000000000000
```

* * *

The bogo value show that CPU is not very fast as expected. To achieve some decent performance I need to learn DSP programming.
