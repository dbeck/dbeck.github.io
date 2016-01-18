---
published: true
layout: post
category: IoT
tags: 
  - IoT
  - igep
  - Linux
desc: Fourth part of my Igep V2 advanture on Gentoo
description: Fourth part of my Igep V2 advanture on Gentoo
keywords: "IGEPv2, IoT, ARM, Gentoo, Linux"
twcardtype: summary_large_image 
twimage: http://dbeck.github.io/images/989/P1010895-large.JPG
woopra: igep4
---

Gentoo has very compelling features and I already have good experiences with it on x86\. I plan to compile the whole Linux distribution from source. This is very time consuming, but rewarding at the same time. My feeling so far is setting the right optimization flags for IGEP makes a big difference. This post is going to be long. This is not a concise howto guide, but rather a collection of information that is not available in the [official Gentoo installation guide.](http://www.gentoo.org/doc/en/handbook/handbook-arm.xml?style=printable&full=1) That document is a good starting point but one needs to know more to decide whether Gentoo would be the one to go with.

### Start

The official install guide is a good starting point to begin with. There are many Stage 3 tarballs we can use on the ARM platform. To be on the safe side I downloaded these three:

1.  stage3-armv5tel-20100220.tar.bz2
2.  stage3-armv6j-20100218.tar.bz2
3.  stage3-armv7a-20100216.tar.bz2

With Ubuntu Lucid I had bad experiences. Some packages were not usable because of platform or compilation flag differences. Here I checked all three if I can chroot into them (after unpacking). All three are working and the precompiled packages were usable. I chose armv7a for my IGEP.

The tarballs are around 120MB each and they consume 442MB each after extracted. This size makes them unusable on the IGEP flash. For this reason I created an NFS share to host this experiment.

### Decide what compilation flags to be used

I found [this article](http://pandorawiki.org/Floating_Point_Optimization) about GCC flags to be used on Omap3 based systems. I decided to set these in the make.conf:

```
 CFLAGS="-O3 -pipe -march=armv7-a -mfpu=neon -mtune=cortex-a8 -mfloat-abi=softfp"
 CXXFLAGS="-O3 -pipe -march=armv7-a -mfpu=neon -mtune=cortex-a8 -mfloat-abi=softfp"
```

I also checked what difference these makes in a simple floating point test app. Apart from the O3 flag the others seem to make very little difference. The GCC manual says that O3 implies -ftree-vectorize so I leave that and -ffast-math has correctness implications, so it may not be suitable for system rebuild.

### Make the chrooted environment working

To have network access I edited the resolv.conf with nano. The whole experiment is done on my IGEP system and the Gentoo files are placed on a NFS share served from my Sheevaplug. For this reason I already had network access and now DNS works too. I also mounted /proc and /dev (not chrooted but inside the extracted stage 3 environment) :

```
 mount -t proc none proc mount -o bind -t bind /dev dev
```

These steps are also needed to make the environment working (more details are in the official guide) :

1.  Update the environment by **env-update**
2.  Syncing the portage tree with **emerge—sync**
3.  I changed the -Os flag to -O3 in make.conf
4.  Update the portage tools with **emerge—oneshot portage**
5.  Choose a profile from **eselect profile list** by **eselect profile set 3** which is the developer profile in my case
6.  edit **/etc/locale.gen**
7.  run **locale-gen**
8.  copy the time zone (which is CET in my case) from /usr/share/zoneinfo/CET to /etc/localtime
9.  **emerge gentoo-sources**
10.  Finally I installed eix which is a very handy too to get information about packages. **emerge eix** and **eix-update**

### What was already inside the Stage 3 tarball

I suspected it contains sensible defaults, the commands in the chrooted environment are working. I noticed in the official guide that neither Beagleboard nor IGEP were on the tested hardware list. Because of these I expected that the default values are failsafe but not optimized for IGEP. The factory supplied make conf:

```
 # These settings were set by the catalyst build script that automatically
 # built this stage.
 # Please consult /usr/share/portage/config/make.conf.example for a more
 # detailed example.
 CFLAGS="-Os -pipe -march=armv7-a -mfpu=vfp -mfloat-abi=softfp" 
 CXXFLAGS="-Os -pipe -march=armv7-a -mfpu=vfp -mfloat-abi=softfp" 
 # WARNING: Changing your CHOST is not something that should be done lightly.
 # Please consult http://www.gentoo.org/doc/en/change-chost.xml before changing.
 CHOST="armv7a-unknown-linux-gnueabi" 
```

The CFLAGS and CXXFLAGS were set to space/performance optimized code while I don’t care that much for space rather I care for speed. My planned optimization flags looked better for IGEP. My plan was to first compile GCC with optimization. I hoped that this will reduce the compilation time of other packages.

I was also interested in the list of preinstalled packages in the tarball:

```
 acl-0                  acl-2.2.47                attr-2.4.43                 autoconf-2.63-r1
 autoconf-wrapper-7     automake-1.10.2           automake-wrapper-3-r1       baselayout-1.12.13
 bash-4.0_p35           binutils-2.19.1-r1        binutils-config-1.9-r4      bison-2.3
 busybox-1.14.2         bzip2-1.0.5-r1            ca-certificates-20090709    coreutils-7.5-r1
 cpio-2.9-r2            cracklib-2.8.13-r1        db-4.7.25_p4                debianutils-3.1.3
 diffutils-2.8.7-r2     e2fsprogs-1.41.9          e2fsprogs-libs-1.41.9       editor-0
 eselect-python-20091230                          expat-2.0.1-r2              file-5.03x
 flex-2.5.35            gawk-3.1.6                gcc-4.3.4                   gcc-config-1.4.1
 gdbm-1.8.3-r4          eselect-1.2.9             eselect-1.2.9               gzip-1.4
 gettext-0.17           glibc-2.10.1-r1           gmp-4.3.2                   gnuconfig-20090819
 grep-2.5.4-r1          groff-1.20.1-r1           init-0                      iputils-20071127
 kbd-1.15               less-436                  libffi-0                    libffi-3.0.8
 libiconv-0             libintl-0                 man-1.6f-r3                 man-pages-3.23
 libpcre-7.9-r1         libperl-5.8.8-r2          libtool-2.2.6b              libxml2-2.7.3-r2
 linux-headers-2.6.27-r2                          m4-1.4.12                   make-3.81
 man-pages-posix-2003a                            mime-types-8                module-init-tools-3.5
 mpfr-2.4.1_p5          nano-2.1.10               ncurses-5.7-r3              pam-1.1.0
 net-tools-1.60_p20071202044231-r1                openssh-5.2_p1-r3           python-updater-0.7
 openssl-0.9.8l-r2      pager-0                   pambase-20090620.1-r1       patch-2.5.9
 pax-utils-0.1.19       perl-5.8.8-r8             perl-cleaner-1.05           popt-1.15
 portage-2.1.7.16       procps-3.2.8              psmisc-22.10                python-2.6.4
 readline-6.0_p4        rsync-3.0.6               sandbox-1.6-r2              sed-4.2
 shadow-4.1.2.2         timezone-data-2009u       zlib-1.2.3-r1     
 sysvinit-2.86-r10      tar-1.20                  tcp-wrappers-7.6-r8         texinfo-4.13
 udev-146-r1            util-linux-2.16.2         wget-1.12                   which-2.20
```

The FEATURES variable is also important for me especially after I bumped into the first issues….

```
 FEATURES="assume-digests collision-protect cvs digest distlocks fixpackages \
           multilib-strict news parallel-fetch protect-owned sandbox sfperms sign \
           splitdebug strict stricter test unmerge-logs unmerge-orphans userfetch \
           userpriv usersandbox"
```

I already overridden the CFLAGS and CXXFLAGS variables in the make.conf but there are other variables could be set and many of them also have default values. They can be queried by **emerge—info | egrep -v’CFLAGS|CXXFLAGS|FEATURES’** :

```
 Portage 2.1.7.17 (default/linux/arm/10.0/developer, gcc-4.3.4, glibc-2.10.1-r1, 2.6.28.10 armv7l)
 =================================================================
 System uname: Linux-2.6.28.10-armv7l-ARMv7_Processor_rev_3_-v7l-with-gentoo-1.12.13
 Timestamp of tree: Fri, 19 Mar 2010 17:30:01 +0000
 app-shells/bash:     4.0_p35
 dev-lang/python:     2.6.4
 sys-apps/baselayout: 1.12.13
 sys-apps/sandbox:    1.6-r2
 sys-devel/autoconf:  2.13, 2.63-r1
 sys-devel/automake:  1.9.6-r3, 1.10.2
 sys-devel/binutils:  2.19.1-r1
 sys-devel/gcc:       4.3.4
 sys-devel/gcc-config: 1.4.1
 sys-devel/libtool:   2.2.6b
 virtual/os-headers:  2.6.27-r2
 ACCEPT_KEYWORDS="arm" 
 ACCEPT_LICENSE="* -@EULA" 
 CBUILD="armv7a-unknown-linux-gnueabi" 
 CHOST="armv7a-unknown-linux-gnueabi" 
 CONFIG_PROTECT="/etc" 
 CONFIG_PROTECT_MASK="/etc/ca-certificates.conf /etc/env.d /etc/gconf /etc/sandbox.d \
                      /etc/terminfo /etc/udev/rules.d" 
 DISTDIR="/usr/portage/distfiles" 
 GENTOO_MIRRORS="http://distfiles.gentoo.org" 
 LANG="en_US.UTF-8" 
 LDFLAGS="-Wl,-O1" 
 PKGDIR="/usr/portage/packages" 
 PORTAGE_CONFIGROOT="/" 
 PORTAGE_RSYNC_OPTS="--recursive --links --safe-links --perms --times --compress \
                     --force --whole-file --delete --stats --timeout=180 --exclude=/distfiles \
                     --exclude=/local --exclude=/packages" 
 PORTAGE_TMPDIR="/var/tmp" 
 PORTDIR="/usr/portage" 
 SYNC="rsync://rsync.gentoo.org/gentoo-portage" 
 USE="X a52 aac acl acpi alsa apache2 arm berkdb bluetooth bzip2 cairo cdr cli consolekit \
     cracklib crypt cups cxx dbus dts dvdr eds emboss encode evo fam firefox flac fortran gdbm \
     gif gnome gpm gstreamer gtk hal iconv ipv6 jpeg kde ldap libnotify mad mikmod mng modules mp3 \
     mp4 mpeg mudflap mysql ncurses nls nptl nptlonly ogg opengl openmp pam pcre pdf perl png ppds \
     pppd python qt3support qt4 quicktime readline reflection sdl session snmp spell spl ssl \
     startup-notification svg sysfs tcpd thunar tiff truetype unicode usb vorbis xml xorg \
     xulrunner xv xvid zlib" 
 ALSA_PCM_PLUGINS="adpcm alaw asym copy dmix dshare dsnoop empty extplug file hooks iec958 \
                   ioplug ladspa lfloat linear meter mmap_emul mulaw multi null plug rate route \
                   share shm softvol" 
 APACHE2_MODULES="actions alias auth_basic authn_alias authn_anon authn_dbm authn_default \
                  authn_file authz_dbm authz_default authz_groupfile authz_host authz_owner \
                  authz_user autoindex cache dav dav_fs dav_lock deflate dir disk_cache env \
                  expires ext_filter file_cache filter headers include info log_config logio \
                  mem_cache mime mime_magic negotiation rewrite setenvif speling status unique_id \
                  userdir usertrack vhost_alias" 
 ELIBC="glibc" 
 INPUT_DEVICES="keyboard mouse evdev" 
 KERNEL="linux" 
 LCD_DEVICES="bayrad cfontz cfontz633 glk hd44780 lb216 lcdm001 mtxorb ncurses text" 
 RUBY_TARGETS="ruby18" 
 USERLAND="GNU" 
 VIDEO_CARDS="fbdev glint mach64 mga nv r128 radeon savage sis tdfx trident voodoo" 
 Unset:  CPPFLAGS, CTARGET, EMERGE_DEFAULT_OPTS, FFLAGS, \
         INSTALL_MASK, LC_ALL, LINGUAS, MAKEOPTS, PORTAGE_COMPRESS, \
         PORTAGE_COMPRESS_FLAGS, PORTAGE_RSYNC_EXTRA_OPTS, \
         PORTDIR_OVERLAY
```

Now I had some infos about the system so I could stick to my plan of installing an optimized and hopefully faster GCC. My first naive attempt was to simply issue **emerge gcc**. I realized that it installs lots of packages that I didn’t know that are related to GCC:

```
 bigreqsproto-1.1.0       inputproto-1.5.1
 kbproto-1.0.4            libICE-1.0.6
 libXau-1.0.5             libXdmcp-1.0.3
 libxslt-1.1.26           renderproto-0.11
 tcl-8.5.7                xcb-proto-1.5
 xcmiscproto-1.2.0        xextproto-7.0.5
 xf86bigfontproto-1.2.0   xproto-7.0.16
 xtrans-1.2.5
```

I couldn’t understand what are these X related libraries are doing with GCC. I didn’t like it but I thought I can live with this for the time being. During the compilation I also found that it also needs scheme/guile and unfortunately it does not install. It compiles but the on of the tests failed:

```
 PASS: test-system-cmds
 PASS: test-require-extension
 PASS: test-bad-identifiers
 PASS: test-num2integral
 PASS: test-round
 PASS: test-gh
 ERROR: In procedure dynamic-link:
 ERROR: file: "libtest-asmobs", message: "file not found" 
 FAIL: test-asmobs
 PASS: test-list
 PASS: test-unwind
 PASS: test-conversion
 PASS: test-use-srfi
 PASS: test-with-guile-module
 ==================================
 1 of 12 tests failed
 Please report to bug-guile@gnu.org
 ==================================
 make[4]: *** [check-TESTS] Error 1
 make[4]: Leaving directory `/var/tmp/portage/dev-scheme/guile-1.8.5-r1/work/guile-1.8.5/test-suite/standalone'
 make[3]: *** [check-am] Error 2
 make[3]: Leaving directory `/var/tmp/portage/dev-scheme/guile-1.8.5-r1/work/guile-1.8.5/test-suite/standalone'
 make[2]: *** [check] Error 2
 make[2]: Leaving directory `/var/tmp/portage/dev-scheme/guile-1.8.5-r1/work/guile-1.8.5/test-suite/standalone'
 make[1]: *** [check-recursive] Error 1
 make[1]: Leaving directory `/var/tmp/portage/dev-scheme/guile-1.8.5-r1/work/guile-1.8.5/test-suite'
```

It complains about this asmobs thingy that I don’t see why do I need for GCC. Later I realized that guile itself is used by autogen… Then I started tweaking the USE flags and the FEATURES variable in make.conf . Finally I realized that I need to replace the **test** flag to **test-fail-continue** for this particular build. I set this in make conf and **emerge —keep-going=True guile** . Then I set it back. I also added **buildpkg** into FEATURES so I could probably use the compiled packages later. I also set **dev-scheme/guile -test** in /etc/portage/package.use

The GCC compilation took something like 8 hours.

### Recompile packages

The next thing is rebuilding the already installed packages. This again takes ages. There are packages that do not install because of test failures. It complains about dynamic loading and pthread. I don’t have the time to look into this issue so I leave the original packages. The packages that have test failures:

*   guile
*   binutils
*   flex
*   libtool

### Lowering requirements

Some of the above mentioned packages did install after I replaced **test** with **test-fail-continue** in the FEATURES settings in make.conf. Git and ncurses still did not install. In case of git the error was:

```
 ERROR: dev-vcs/git-1.6.4.4 failed:
   Aborting due to QA concerns:  execstacks
```

For a temporary solution I changed **stricter** to **-stricter** in FEATURES. This will be changed back as I prefer **stricter**.

### Compiling the kernel

For booting the device I need a uImage kernel so I emerged **emerge dev-embedded/u-boot-tools**. I downloaded the kernel sources from the IGEP site “http://downloads.myigep.com/sources/kernel/linux-omap-2.6.28.10.2-igep0020b-2.tar.gz” . The compilation steps are copied [from IGEP Wiki](http://wiki.myigep.com/trac/wiki/HowToCrossCompileTheLinuxKernel) and corrected to match my gentoo environment:

```
 make ARCH=arm CROSS_COMPILE=armv7a-unknown-linux-gnueabi- igep0020b_defconfig
 make ARCH=arm CROSS_COMPILE=armv7a-unknown-linux-gnueabi- uImage modules modules_install
```

I checked what the resulting .config file was after **igep0020b_defconfig** and compared that to the factory supplied .config. The differences were (comments omitted):

```
 578,588c578
 < CONFIG_MTD_NAND=y
 ...
 < CONFIG_MTD_NAND_OMAP2=y
 < CONFIG_MTD_NAND_IDS=y
 ...
 < CONFIG_MTD_NAND_PLATFORM=y
 ---
 > # CONFIG_MTD_NAND is not set
 1701a1692,1699
 > CONFIG_MPU_BRIDGE=m
 > CONFIG_BRIDGE_MEMPOOL_SIZE=0x600000
 ...
```

Finally I configured my kernel based on the default igep configuration. I disabled space optimization because I prefer speed over space in my case. I added NFS server and CIFS support. Then I built my new kernel.

### Package repository

Many packages compiled as expected and some had minor issues. So far all of them are working. My ultimate goal is to make my IGEP a desktop machine based on Gentoo. Now I have everything in place for a console based Gentoo setup and I’m successfully using it over NFS. I share the packages I built [at this location.](http://dbeck.beckground.hu/gentoo/igep-packages/) I publish my newly build packages from time to time. The binaries are shared on a goodwill bases and the ususal BSD disclaimer applies. Use it on your on risk, etc… All binaries stay under their original licenses that you can find in the portage database.


