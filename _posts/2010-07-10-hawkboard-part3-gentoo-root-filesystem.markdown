---
published: false
layout: post
category: IoT
tags:
  - IoT
  - hawkboard
  - Linux
desc: Hacking Gentoo onto my HawkBoard
description: Hacking Gentoo onto my HawkBoard
keywords: "Hawkboard, IoT, ARM, Linux, Gentoo"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/1091/P1020018-large.JPG
pageid: hawkboard3
---

I share my Gentoo root filesystem for Hawkboard. It does not support a GUI and it has other issues too. I describe the process of flashing a SATA ready kernel and also set the U-Boot parameters to boot that. I believe the Gentoo philosophy is very practical for embedded devices. Gentoo users normally compile everything from source and it has a smart system to fine tune the compilation procedure. Embedded users often have special needs so this can be a big advantage. The compilation is very time consuming so I share the compiled binary packages as well.

### My Gentoo Root FS

[The root filesystem is available here.](http://dbeck.beckground.hu/gentoo/hawkboard-goodies/gentoo-rootfs-100710.tar.bz2)

1.  It assumes you configure your network by passing the right kernel parameters from U-Boot (this can be changed in /etc/conf.d/net)
2.  It assumes that **/dev/sda1** is your root filesystem and **/dev/sda2** is your swap (this can be changed in fstab)
3.  There is a **root** and a **hawk** user and their password is **password**
4.  The uncompressed size is around 1,2 GB

### How to set U-Boot

To change U-Boot settings you need a serial cable. The connection settings has to be set to 115200 8N1\. U-Boot automatically boots the system but before that it counts down and waits for keyboard input. Push a space and you are in. You should see a **‘hawkboard.org >‘** prompt.

The process here is largely inspired by [Gaston’s post at hawkboard.wordpress.com.](http://hawkboard.wordpress.com/2010/05/18/ymodem-transfer-of-the-uimage-file-on-hawkboard-by-gaston/)

U-Boot loader is pretty smart. Complete programs can be written with its commands. Here I focus on simple things. I want to flash my [new kernel](http://dbeck.beckground.hu/gentoo/hawkboard-goodies/uImage_oe-2.6.33-rc4-B) (almost the same as [the previous](http://dbeck.beckground.hu/articles/2010/07/03/hawkboard-part-2-gentoo-sata-ti/) but I added NAND support and removed SATA PMP)

I access the new kernel through TFTP:

```
hawkboard.org > set machine hawkboard
hawkboard.org > set boot-kernel uImage_oe-2.6.33-rc4-B
hawkboard.org > tftp c0700000 ${machine}/${boot-kernel}
TFTP from server 192.168.1.88; our IP address is 192.168.1.55
Filename 'hawkboard/uImage_oe-2.6.33-rc4-B'.

Load address: 0xc0700000
Loading: #################################################################
         #################################################################
         #################################################################
         #################################################################
         #################################################################
         #################################################################
         #########################################
done
Bytes transferred = 2204592 (21a3b0 hex)

```

Now I loaded the kernel to 0xc0700000 address and the next step is to write it to the flash. I know the kernel should start at 0×200000 and the kernel size is 0×21a3b0\. I will write slightly bigger amount to be on the safe side (0×220000). I also know the flash partition is bigger than this and also there is nothing useful on the flash apart from U-Boot stuff. So I will erase and write that part of the flash.

```
hawkboard.org > nand erase 0x200000 0x220000

NAND erase: device 0 offset 0x200000, size 0x220000
Erasing at 0x400000 -- 100% complete.
OK

hawkboard.org > nand write.e 0xc0700000 0x200000 0x220000

NAND write: device 0 offset 0x200000, size 0x220000
 2228224 bytes written: OK
```

When modifying U-Boot environment I usually create new environment variables and leave the old ones for reference.

```
hawkboard.org > set newboot 'run newboot-args; nand read.e 0xc0700000 0x200000 0x220000; bootm 0xc0700000'
hawkboard.org > set newboot-base 'mem=128M console=ttyS2,115200n8'
hawkboard.org > set newboot-args 'setenv bootargs ${newboot-base} noinitrd root=/dev/sda1 rootwait rw init=/sbin/init ip=dhcp'
hawkboard.org > set bootcmd 'run newboot'
hawkboard.org > saveenv
Saving Environment to NAND...
Erasing Nand...
Erasing at 0x0 -- 100% complete.
Writing to Nand... done
```

The kernel should be ready and you can boot by **‘run newboot’**. The system now automatically starts this when rebooted because we modified **bootcmd**.

### fstab

I have my root filesystem on /dev/sda1 and my swap on /dev/sda2\. If you use an SD Card then the fstab must be modified accordingly. Here is the fstab in my root fs (comments omitted):

```
/dev/sda1        /        ext3        noatime        0 1
/dev/sda2        none        swap        sw        0 0
shm            /dev/shm    tmpfs        nodev,nosuid,noexec    0 0
```

For an SD Card you probably want /dev/mmcblk0p1 as a root filesystem.

### setting date / ntpdate

My Gentoo system is based on the official stage3 tarball. I added a few packages and modified settings to make it usable on the Hawkboard. The Gentoo init system doesn’t like the fact that the clock is set to Epoch at boot. It complains a lot:

```
 * One of the files in /etc/{conf.d,init.d} or /etc/rc.conf
 * has a modification time in the future!
```

These messages will only stop when ntp-client service was started. I found that many things depend on the correct time. One of these is PAM. You cannot add user and change password until it was not set. I haven’t got the time to debug this, so if you have no network access and NTP would not work you best set the date by ‘date —set=’Sat Jul 3 11:59:14 CEST 2010’

### Already installed packages

The stage3 tarball missed many packages I usually need. Not all of them are strictly necessary, but some of the are definitely useful. These are installed in my root fs tarball:

```
app-admin/eselect        app-admin/eselect-ctags        app-admin/eselect-python        app-admin/eselect-ruby
app-admin/eselect-vi     app-admin/perl-cleaner         app-admin/python-updater        app-admin/sudo
app-arch/bzip2           app-arch/cpio                  app-arch/gzip                   app-arch/tar
app-arch/unzip           app-arch/xz-utils              app-editors/gentoo-editor       app-editors/gvim
app-editors/nano         app-editors/vim                app-editors/vim-core            app-misc/ca-certificates
app-misc/mime-types      app-misc/pax-utils             app-portage/eix                 app-shells/bash
app-vim/cream            app-vim/gentoo-syntax          dev-lang/perl                   dev-lang/python
dev-lang/ruby            dev-libs/expat                 dev-libs/gmp                    dev-libs/libffi
dev-libs/libgcrypt       dev-libs/libgpg-error          dev-libs/libpcre                dev-libs/libpthread-stubs
dev-libs/libxml2         dev-libs/libxslt               dev-libs/lzo                    dev-libs/mpfr
dev-libs/openssl         dev-libs/popt                  dev-perl/TermReadKey            dev-python/setuptools
dev-util/ccache          dev-util/cmake                 dev-util/cscope                 dev-util/ctags
dev-util/pkgconfig       dev-util/ragel                 dev-vcs/git                     dev-vcs/git-sh
mail-mta/ssmtp           net-analyzer/net-snmp          net-mail/mailbase               net-misc/curl
net-misc/dhcp            net-misc/iputils               net-misc/ntp                    net-misc/openssh
net-misc/rsync           net-misc/wget                  sys-apps/acl                    sys-apps/attr
sys-apps/baselayout      sys-apps/busybox               sys-apps/coreutils              sys-apps/debianutils
sys-apps/diffutils       sys-apps/file                  sys-apps/findutils              sys-apps/gawk
sys-apps/grep            sys-apps/groff                 sys-apps/kbd                    sys-apps/less
sys-apps/man             sys-apps/man-pages             sys-apps/man-pages-posix        sys-apps/module-init-tools
sys-apps/net-tools       sys-apps/portage               sys-apps/sandbox                sys-apps/sed
sys-apps/shadow          sys-apps/sysvinit              sys-apps/tcp-wrappers           sys-apps/texinfo
sys-apps/util-linux      sys-apps/which                 sys-auth/pambase                sys-devel/autoconf
sys-devel/autoconf-wrapper                              sys-devel/automake              sys-devel/automake-wrapper
sys-devel/binutils       sys-devel/binutils-config      sys-devel/bison                 sys-devel/flex
sys-devel/gcc            sys-devel/gcc-config           sys-devel/gettext               sys-devel/gnuconfig
sys-devel/libperl        sys-devel/libtool              sys-devel/m4                    sys-devel/make
sys-devel/patch          sys-fs/e2fsprogs               sys-fs/mtd-utils                sys-fs/udev
sys-kernel/linux-headers sys-libs/cracklib              sys-libs/db                     sys-libs/e2fsprogs-libs
sys-libs/gdbm            sys-libs/glibc                 sys-libs/gpm                    sys-libs/ncurses
sys-libs/pam             sys-libs/readline              sys-libs/timezone-data          sys-libs/zlib
sys-process/cronbase     sys-process/procps             sys-process/psmisc              sys-process/vixie-cron
virtual/acl              virtual/editor                 virtual/init                    virtual/libffi
virtual/libiconv         virtual/libintl                virtual/pager                   x11-libs/libICE
x11-libs/libSM           x11-libs/libX11                x11-libs/libXau                 x11-libs/libXaw
x11-libs/libXdmcp        x11-libs/libXext               x11-libs/libXmu                 x11-libs/libXpm
x11-libs/libXt           x11-libs/libxcb                x11-libs/xtrans                 x11-misc/util-macros
x11-proto/inputproto     x11-proto/kbproto              x11-proto/xcb-proto             x11-proto/xextproto
x11-proto/xf86bigfontproto                              x11-proto/xproto
```

Some of these packages were already part of the stage3 tarball like find utils, flex and bison. I installed many others like git, cmake, ragel and mtd utils.

### My Gentoo packages for Hawkboard

I collect the binary packages I compile and publish them [at this location](http://dbeck.beckground.hu/gentoo/hawkboard-packages/)

### Disclaimer

The usual crap. Every information here are collected on a best effort bases. There is no warranty that these work and no liability for any damage. Use at your own risk. If you download any binary package than you accept its license.
