---
published: false
layout: post
category: IoT
tags:
  - IoT
  - smartq
desc: Getting started with my SmartQ V7
description: Getting started with my SmartQ V7
keywords: "SmartQ, IoT, ARM"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/1157/P1020036-large.JPG
woopra: smartq
---

I chose an ARM based MID to experiment with. This guy is able to play Full-HD videos with low power consumption. The SmartQ V7 I bought is far from the build quality of IPad but far cheaper and has lot more connectors by default. Three operating systems can be chosen during the device boot. All of them is set to Chinese so it takes some time to change language. Actually WinCE has to be upgraded in order to switch language. With Linux it is pretty easy and it takes some time to set on Android.

### Shipping

I ordered this item from DealExtreme and I liked the whole process. First of all they do free shipping. When I check prices I don’t need to worry about the shipping cost. I chose Hong Kong Post delivery which has some basic tracking information but they don’t update it frequently. When it displayed the item left Hong Kong it actually arrived. I had the device in three weeks which is not bad given that the shipping cost me nothing.

### How it looks like

[![](/images/1157/P1020036-icon.JPG)](/images/1157/P1020036-large.JPG "SmartQ V7")[![](/images/1199/P1020044-icon.JPG)](/images/1199/P1020044-large.JPG "SmartQ V7")[![](/images/1163/P1020037-icon.JPG)](/images/1163/P1020037-large.JPG "SmartQ V7")[![](/images/1205/P1020045-icon.JPG)](/images/1205/P1020045-large.JPG "SmartQ V7")[![](/images/1169/P1020039-icon.JPG)](/images/1169/P1020039-large.JPG "SmartQ V7")[![](/images/1211/P1020046-icon.JPG)](/images/1211/P1020046-large.JPG "SmartQ V7")[![](/images/1175/P1020040-icon.JPG)](/images/1175/P1020040-large.JPG "SmartQ V7")[![](/images/1217/P1020047-icon.JPG)](/images/1217/P1020047-large.JPG "SmartQ V7")[![](/images/1181/P1020041-icon.JPG)](/images/1181/P1020041-large.JPG "SmartQ V7")[![](/images/1187/P1020043-icon.JPG)](/images/1187/P1020043-large.JPG "SmartQ V7")

This pearlish color is not my taste, but I’m more interested in the internals. The device has a pretty big screen. Bigger than it looked like on the pictures.

### OS selection

It is a very nice feature that I can choose operating system after boot. I did not bother with WinCE and Android. This post is about Linux experiences. It automatically detects my Wireless network. I also like the selection of the installed programs. A bit of everything. Nothing for development but for an average user it is fine. The fonts are too big even close to make it unusable, so my first move was to set it smaller.

### The CPU

* * *

```
user@SmartQ:~$ cat /proc/cpuinfo
Processor    : ARMv6-compatible processor rev 6 (v6l)
BogoMIPS    : 53.90
Features    : swp half thumb fastmult vfp edsp java
CPU implementer    : 0x41
CPU architecture: 7
CPU variant    : 0x0
CPU part    : 0xb76
CPU revision    : 6

Hardware    : Telechips TCC8900 Demo Board
Revision    : AX
Serial        : 0000000000000000
```

* * *

The DealExtreme website says its a Samsung CPU at 667 MHZ. According to the specs this device can play Full HD videos so there must be something in addition. The “TCC8900” string gives useful results in Google. I suspect that Samsung licensed or bought this chip from Telechips. The core includes a GPU developed by ARM and is called Mali 200\. That’s the one that is able to play high resolution videos.

### Kernel output

* * *

```
Linux version 2.6.28 (root@yousheng) (gcc version 4.3.2 (Sourcery G++ Lite 2008q3-72) ) #908 PREEMPT Fri Mar 12 16:32:21 CST 2010
mem_flag = 2
CPU: ARMv6-compatible processor [410fb766] revision 6 (ARMv7), cr=00c5387f
CPU: VIPT nonaliasing data cache, VIPT nonaliasing instruction cache
Machine: Telechips TCC8900 Demo Board
Warning: bad configuration page, trying to continue
Memory policy: ECC disabled, Data cache writeback
create_mapping:0x40200000->0xc0000000(0x8a00000)
On node 0 totalpages: 35328
free_area_init_node: node 0, pgdat c03ef890, node_mem_map c04aa000
  Normal zone: 276 pages used for memmap
  Normal zone: 0 pages reserved
  Normal zone: 35052 pages, LIFO batch:7
  Movable zone: 0 pages used for memmap
create_mapping:0x407bf000->0xffff0000(0x1000)
create_mapping:0xf0000000->0xf0000000(0x100000)
create_mapping:0xf0100000->0xf0100000(0x100000)
create_mapping:0xf0200000->0xf0200000(0x100000)
create_mapping:0xf0300000->0xf0300000(0x100000)
create_mapping:0xf0400000->0xf0400000(0x100000)
create_mapping:0xf0500000->0xf0500000(0x100000)
create_mapping:0xf0600000->0xf0600000(0x100000)
create_mapping:0xf0700000->0xf0700000(0x100000)
create_mapping:0x10000000->0xeff00000(0x100000)
TCC8902 Power Management, (c) 2009 HHCN
Built 1 zonelists in Zone order, mobility grouping on.  Total pages: 35052
Kernel command line: console=ttySAC0,115200n8 root=/dev/ndda1 rw rootwait splash quiet mem=138M
tcc8900_irq_init
PID hash table entries: 1024 (order: 10, 4096 bytes)
 ### CORE CLOCK (540000000 Hz), BUS CLOCK (330000000 Hz) ###
Console: colour dummy device 80x30
console [ttySAC0] enabled
Dentry cache hash table entries: 32768 (order: 5, 131072 bytes)
Inode-cache hash table entries: 16384 (order: 4, 65536 bytes)
_etext:0xc03d2000, _text:0xc011a000, _end:0xc04a3d14, __data_start:0xc03d2000, __init_end:0xc011a000, __init_begin:0xc0100000
Memory: 138MB = 138MB total
Memory: 136076KB available (2784K code, 839K data, 104K init)
SLUB: Genslabs=12, HWalign=32, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
Calibrating delay loop... 539.03 BogoMIPS (lpj=1347584)
Mount-cache hash table entries: 512
CPU: Testing write buffer coherency: ok
net_namespace: 424 bytes
NET: Registered protocol family 16
usbcore: registered new interface driver usbfs
usbcore: registered new interface driver hub
usbcore: registered new device driver usb
NET: Registered protocol family 2
IP route cache hash table entries: 2048 (order: 1, 8192 bytes)
TCP established hash table entries: 8192 (order: 4, 65536 bytes)
TCP bind hash table entries: 8192 (order: 3, 32768 bytes)
TCP: Hash tables configured (established 8192 bind 8192)
TCP reno registered
NET: Registered protocol family 1
Telechips Dynamic Power Management.
msgmni has been set to 266
alg: No test for stdrng (krng)
io scheduler noop registered
io scheduler cfq registered (default)
i2c-gpio i2c-gpio.4: using pins 102 (SDA) and 101 (SCL)
i2c0 SCK(50) <-- input clk(40000Khz), prescale(15)
i2c1 SCK(50) <-- input clk(40000Khz), prescale(15)
tcc-i2c tcc-i2c: i2c-0: I2C adapter
i2c-tcc: time out!
send_i2c failed
fb[0]::map_video_memory: dma=48c00000 cpu=ca000000 size=00800000
fb0: tccfb frame buffer device
fb[1]::map_video_memory: dma=49400000 cpu=c9800000 size=00400000
fb1: tccfb frame buffer device
fb[2]::map_video_memory: dma=49800000 cpu=cb000000 size=00400000
fb2: tccfb frame buffer device
tcc_pwm: init (ver 0.1)
tcc_intr: init (ver 2.1)
bl: init
tcc proc filesystem initialised
pwrkey: init
tcc8900-uart.0: tcc-uart0 at MMIO 0xf0532000 (irq = 64) is a uart0
brd: module loaded
[NAND        ] [BClk 156MHZ][1Tick 65][RE-S:0,P:5,H:2][WR-S:0,P:3,H:2][COM-S:2,P:15,H:7]
[NAND        ] [NB Area:4MB][DT Area:1796MB][HD Area0:120MB]
 ndda: ndda1 ndda2 ndda3 ndda4 < >
[tcc_nand] init ndd(TCC8900, V7014)
TRACE: DPM is now installed
ohci_hcd: USB 1.1 'Open' Host Controller (OHCI) Driver
tcc-ohci tcc-ohci: TCC OHCI
tcc-ohci tcc-ohci: new USB bus registered, assigned bus number 1
tcc-ohci tcc-ohci: irq 49, io mem 0xf0500000
usb usb1: configuration #1 chosen from 1 choice
hub 1-0:1.0: USB hub found
hub 1-0:1.0: 1 port detected
mice: PS/2 mouse device common for all mice
Telechips Touchscreen driver, (c) 2009 Telechips
tcc-ts got loaded successfully.
input: tcc-ts as /devices/platform/tcc-ts/input/input0
TCC RTC, (c) 2009, Telechips
tcc-rtc tcc-rtc: rtc core: registered tcc-rtc as rtc0
tcc-sdhc0: init
--- err --- already exist dev-node !!! -> id[8]
tcc-sdhc1: init
Advanced Linux Sound Architecture Driver Version 1.0.18rc3.
ASoC version 0.13.2
TCC Board probe [tcc_board_probe]
WM8987 Audio Codec 0.12== alsa-debug == tcc_pcm_preallocate_dma_buffer size [65536]
== alsa-debug == tcc_pcm_preallocate_dma_buffer size [65536]
asoc: WM8987 <-> tcc-i2s mapping ok
Proc-FS interface for audio codec
ALSA device list:
  #0: tccx_board (WM8987)
TCP cubic registered
VFP support v0.3: implementor 41 architecture 1 part 20 variant b rev 5
HDMI Driver ver. 1.2 (built Mar  2 2010 11:52:38)
audio_init
HDMI Audio Driver ver. 1.1 (built Mar  2 2010 11:52:37)
PCLK_DAI  : 1200062d
PCLK_SPDIF: 0a000000
PCLK_DAI  : 1200062d
PCLK_SPDIF: 1200062d
HPD Driver ver. 1.2 (built Mar  2 2010 11:52:40)
input: gpio-keys as /devices/platform/gpio-keys.0/input/input1
mmc1: new SDIO card at address 0001
tcc-rtc tcc-rtc: setting system clock to 2010-05-25 20:51:37 UTC (1274820697)
EXT3-fs warning: checktime reached, running e2fsck is recommended
EXT3 FS on ndda1, internal journal
EXT3-fs: mounted filesystem with ordered data mode.
VFS: Mounted root (ext3 filesystem).
Freeing init memory: 104K
kjournald starting.  Commit interval 600 seconds
8686 sdio: sd 8686 driver
8686 sdio: Copyright HHCN 2009
kjournald starting.  Commit interval 600 seconds
EXT3 FS on ndda2, internal journal
EXT3-fs: mounted filesystem with ordered data mode.
i2c /dev entries driver
dwc_otg: version 2.60a 22-NOV-2006
dwc_otg_driver_probe(c03d71a0)
base=0xf0550000
dwc_otg_device=0xc74a78c0
DVBUS_ON power OFF
PWR_GP1  power OFF
DVBUS_ON power OFF
PWR_GP1  power OFF
dwc_otg dwc_otg.0: DWC OTG Controller
dwc_otg dwc_otg.0: new USB bus registered, assigned bus number 2
dwc_otg dwc_otg.0: irq 48, io mem 0x00000000
DVBUS_ON power OFF
PWR_GP1  power OFF
usb usb2: configuration #1 chosen from 1 choice
hub 2-0:1.0: USB hub found
hub 2-0:1.0: 1 port detected
Set ID to host mode
NET: Registered protocol family 17
usb 2-1: new high speed USB device using dwc_otg and address 2
usb 2-1: Dual-Role OTG device on HNP port
usb 2-1: device v0525 pa4a2 is not supported
usb 2-1: configuration #1 chosen from 2 choices
usb0: register 'cdc_ether' at usb-DWC OTG Controller-1, CDC Ethernet Device, 0a:b0:91:9b:d8:d3
usbcore: registered new interface driver cdc_ether
usb 2-1: USB disconnect, address 2
usb0: unregister 'cdc_ether' usb-DWC OTG Controller-1, CDC Ethernet Device
PM: Syncing filesystems ... done.
Freezing user space processes ... (elapsed 0.03 seconds) done.
Freezing remaining freezable tasks ... (elapsed 0.00 seconds) done.
Suspending console(s) (use no_console_suspend to debug)
mmc1: card 0001 removed
Set ID to device mode
ID change ISR : Device
DVBUS_ON power OFF
PWR_GP1  power OFF
!!!tcc8902_getspeed
selfrefresh_test
!!!tcc8902_getspeed
i2c0 SCK(50) <-- input clk(40000Khz), prescale(15)
i2c1 SCK(50) <-- input clk(40000Khz), prescale(15)
!!!tcc8902_getspeed
DVBUS_ON power OFF
PWR_GP1  power OFF
soc-audio soc-audio: scheduling resume work
soc-audio soc-audio: starting resume work
Restarting tasks ... Set ID to host mode
ID change ISR : Host
mmc1: new SDIO card at address 0001
done.
```

* * *

The output shows that the kernel was compiled with the Code Sourcery toolchain. The device calculated 539.03 BogoMIPS that is a lot more realistic than the cpuinfo’s 53.90\. It looks like the core slows down itself when not needed. The filesystem is also interesting. I don’t see why did they put EXT3 on the NAND device. JFFS2 or UBIFS is a more common choice for NAND flashes.

### xorg.conf

* * *

```
 root@SmartQ:~# cat /etc/X11/xorg.conf
 # xorg.conf (X.Org X Window System server configuration file)
 #
 # This file was generated by dexconf, the Debian X Configuration tool, using
 # values from the debconf database.
 #
 # Edit this file with caution, and see the xorg.conf manual page.
 # (Type "man xorg.conf" at the shell prompt.)
 #
 # This file is automatically updated on xserver-xorg package upgrades *only*
 # if it has not been modified since the last upgrade of the xserver-xorg
 # package.
 #
 # If you have edited this file but would like it to be automatically updated
 # again, run the following command:
 #   sudo dpkg-reconfigure -phigh xserver-xorg

 Section "InputDevice"
     Driver         "tslib"
     Identifier     "touchscreen-tslib"
     Option "Device" "/dev/input/event0"

     Option "Width"     "800"
     Option "Height" "480"
     Option "Rotate" "NONE"
     option "EmulateRightButton"    "1"
 Endsection

 Section "InputDevice"
     Driver         "evtouch"
     Identifier     "touchscreen-evtouch"

     Option "Device" "/dev/input/event0"
     #Option "DeviceName" "evtouch touchscreen"

     Option "ReportingMode"     "Raw"
     Option "SendCoreEvents" "On"

     #Option "Calibrate" "1"
         Option "MinX" "2481"
         Option "MinY" "5253"
         Option "MaxX" "14775"
         Option "MaxY" "12559"

     #Option "Emulate3Timeout"     "50"
     #Option "Emulate3Buttons"    "true"
 #     Option "LongTouchTimer"     "200"
 #    Option "TapTimer"         "400"
 #    Option "MoveLimit"         "30"

 #    Option "Rotate" "ccw"     # "cw"
 #    Option "SwapX"     "false"
     Option "SwapY"     "true"

 #    Option "maybetapped_action"     "click"
 #    Option "maybetapped_button"     "2"
 #    Option "longtouch_action"     "down"
 #    Option "longtouch_button"     "3"
 EndSection

 Section "InputDevice"
     Identifier     "dummy"
     Driver         "void"
     Option "Device" "/dev/input/mice"
 EndSection

 Section "InputDevice"
     Driver         "evdev"
     Identifier     "keyboard-evdev"
     Option "Device" "/dev/input/event1"
     Option "GrabDevice" "true"
 Endsection

 Section "InputDevice"
     Driver         "evdev"
     Identifier     "keypwr-evdev"
     Option "Device" "/dev/input/event2"
     Option "GrabDevice" "true"
 Endsection

 Section "InputDevice"
     Identifier    "Generic Keyboard"
     Driver        "kbd"
     Option        "XkbRules"    "xorg"
     Option        "XkbModel"    "pc105"
     Option        "XkbLayout"    "us"
 EndSection

 Section "InputDevice"
     Identifier    "Configured Mouse"
     Driver        "mouse"
     #Option        "CorePointer"
 EndSection

 Section "Device"
     Identifier    "Configured Video Device"
     Option        "UseFBDev"    "true"
     Option        "fbdev"        "/dev/fb2"
     Driver        "fbdev"
 EndSection

 Section "Monitor"
     Identifier    "Configured Monitor"
 EndSection

 Section "Screen"
     Identifier    "Default Screen"
     Monitor        "Configured Monitor"
     Device        "Configured Video Device"
 EndSection

 Section "ServerLayout"
     Identifier    "Default Layout"
     Screen        "Default Screen"

     #InputDevice     "dummy"
     InputDevice     "Configured Mouse"
     InputDevice     "touchscreen-tslib" "CorePointer"
     #InputDevice     "touchscreen-evtouch" "CorePointer"

     InputDevice     "keyboard-evdev"
     InputDevice     "keypwr-evdev"
 EndSection
```

* * *

The interesting part is the video driver. It uses the standard framebuffer driver rather than a Mali 200 specific driver. I tried to find one but I haven’t.

### Free space

* * *

```
user@SmartQ:~$ df -h
Filesystem            Size  Used Avail Use% Mounted on
/dev/ndda1            1.1G  533M  496M  52% /
/dev/ndda2            124M   13M  106M  11% /home
```

* * *

There is very little space left for the user.

### Boot console

I was somehow expecting that an ARM device must use U-Boot so I can easily tweak boot settings. I was wrong. It has a Telechips Bootloader which I don’t know at all. This tweaking has to wait. I was expecting some serial console output but I coudn’t find any way to grab that. I don’t know what ttySAC0 device really is (the boot console), so I have to find out what’s that.

### Future plans

I want to see if I can put a decent Gentoo distro on this. Also booting from NFS would make my life a bit easier when tweaking this device.
