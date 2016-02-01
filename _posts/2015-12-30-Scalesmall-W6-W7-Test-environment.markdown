---
published: true
layout: post
category: Elixir
tags:
  - elixir
  - scalesmall
  - IoT
  - hawkboard
  - bananapi
  - orangepi
desc: ScaleSmall Experiment Week Six and Seven / Test environment
description: ScaleSmall Experiment Week Six and Seven / Test environment
keywords: "Elixir, Distributed, Erlang, Scalable, Test, Environment"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF6707.JPG
woopra: scalesmallw6
scalesmall_subscribe: true
---

I spent the past two weeks with creating my hardware test environment. This was a background task for long. I already had a few components around and I slowly ordered others when I decided how the env should look like. Before Christmas all components arrived so I could start soldering, drilling and cabling this bodge together:

![bodge](/images/DSCF6707.JPG)

### What it is

This testbed has 5 machines:

- 3 x [Hawkboard rev A](https://hawkboard.wordpress.com) + 250 GB HDD
- 1 x [Banana Pi M1](http://www.banana-pi.com/eacp_view.asp?id=35) + 60 GB SSD
- 1 x [Orange Pi Plus](http://www.orangepi.org) + 500 GB HDD

I spent around 10 days out of the two weeks with adding two other machines I have, but finally I gave up: the [Igep V2](/igep-v2-part1-first-impressions/) and the [SheevaPlug](/sheevaplug-experiences/) are not going to be part of this experiment. (It is an interesting story by itself about how painful it is to use an open source Arm board that was fancy 5 years ago and now the support is pretty much gone.)

### The Hawkboards

![hawkboard](/images/hawkboard-a.png)

I bought the Hawkboards five years ago because I wanted to experiment with a distributed filesystem. My time allocated for this has disappeared for family reasons. As the kids grow I am slowly having more time and I decided to resurrect these machines. It turned out that my [5 years old blogposts](/hawkboard-part3-gentoo-root-filesystem/) helped the most with the Hawkboards.

The Hawkboard itself is a painfully slow machine. It has 128 MB RAM and a very slow CPU. (It took a day to compile a Linux kernel on the board.)  The good point is that it has a SATA connector. I originally wanted to use its DSP coprocessor to off-load compression or may be other tasks, but that is not in scope for scalesmall.

For this test environment it is actually an advantage to be slow, because it makes easy to test how machines with different capacities can work together. The goal is to make sure that a slow machine doesn't slow down the faster ones, or the system as a whole. Plus I want the slow machines to actually be useful for the system and to be able to do meaningful work and make the whole faster. I have a few ideas about splitting the load between unequal machines.

### Banana Pi M1

![banana pi m1](/images/banana-pi-m1.jpg)

I purchased this [Banana Pi M1](http://www.aliexpress.com/item/Original-BPI-M1-A20-Dual-Core-1GB-RAM-Open-source-development-board-singel-board-computer-free/32341666319.html) for this experiment a month ago from Aliexpress for $34 including shipping.

Setting up the board was like a breeze, the easiest of all. The other great feature of the board is that it has an Allwinner A20 SOC that has inbuilt SATA support as opposed to the Orange Pi which uses an USB to SATA bridge for connecting the disk. This difference can be clearly seen on the SATA speed. I can read 100MB/s from the SSD which is impossible with the Orange Pi.

### Orange Pi Plus

![orange pi plus](/images/orange-pi-plus.jpg)

I bought the
[Orange Pi Plus](http://www.aliexpress.com/item/Orange-Pi-plus-H3-Quad-Core-1-6GHZ-1GB-RAM-4K-Open-source-development-board-banana/32248189300.html) for this experiment recently from Aliexpress for $43.05 including shipping.

The main strength of the board is the quad core CPU running at 1.6 GHZ. This is the fastest in the testbed. The SATA speed is limited by the USB-SATA bridge. I measure 30MB/s sequential reads from the disk.

### Power supplies

![power supplies](/images/power-supply.jpg)

I bought four of  [these 5A/5v power supplies ](http://www.aliexpress.com/item/Switch-Power-Supply-for-Led-Strip-AC-100V-240V-to-DC-5V-5A-25W-Power-Controller/1953835503.html) from Aliexpress for $22.12 including shipping.

I could have used a single power supply for all the boards and the disks. I decided to use 4 separate ones so I can do nasty things when testing failover. Like switching the power off for a board. This allows me easily simulating hard crash situations.

### Rough speed differences

I use my TCP test applications to compare the boards. [More about the TCP test codes here](/Wrapping-up-my-Elixir-TCP-experiments/). The last two columns are [my non-scientific measurements](/Non-Scientific-Measurement-of-Elixir-Remote-Calls/) of the Elixir local and remote calls.

<p>
<table>
  <tr>
    <th>&nbsp;</th>
    <th>Request<br/>Reply</th>
    <th>Throttle</th>
    <th>Head<br/>Rest</th>
    <th>Sync<br/>Ack</th>
    <th>Async<br/>Ack</th>
    <th>SATA<br/>Read</th>
    <th>Local<br/>call</th>
    <th>Remote<br/>call</th>
  </tr>
  <tr>
    <td>Hawkboard</td>
    <td>680 call/s</td>
    <td>855 call/s</td>
    <td>2426 call/s</td>
    <td>41 k call/s</td>
    <td>52 k call/s</td>
    <td>24.5 MB/s</td>
    <td>5.478 us</td>
    <td>21.317 us</td>
  </tr>
  <tr>
    <td>Banana Pi</td>
    <td>6.1 k call/s</td>
    <td>8.9 k call/s</td>
    <td>19 k call/s</td>
    <td>365 k call/s</td>
    <td>310 k call/s</td>
    <td>100 MB/s</td>
    <td>0.877 us</td>
    <td>4.068 us</td>
  </tr>
  <tr>
    <td>Orange Pi</td>
    <td>6.3 k call/s</td>
    <td>6.5 k call/s</td>
    <td>17 k call/s</td>
    <td>390 k call/s</td>
    <td>330 k call/s</td>
    <td>30 MB/s</td>
    <td>0.409 us</td>
    <td>2.161 us</td>
  </tr>
</table>
</p>

### Hardware comparison

<p>
<table>
  <tr>
    <th>&nbsp;</th>
    <th>Hawkboard</th>
    <th>Orange Pi<br/>Plus</th>
    <th>Banana Pi<br/>M1</th>
  </tr>
  <tr>
    <td>CPU</td>
    <td>TI OMAP L138</td>
    <td>Allwinner H3</td>
    <td>Allwinner A20</td>
  </tr>
  <tr>
    <td>Clock speed x Cores</td>
    <td>456 MHz x 1</td>
    <td>1.6 GHz x 4</td>
    <td>1 GHz x 2</td>
  </tr>
  <tr>
    <td>RAM</td>
    <td>128 MB</td>
    <td>1 GB</td>
    <td>1 GB</td>
  </tr>
  <tr>
    <td>Network</td>
    <td>100 Mb</td>
    <td>1 Gb + Wifi</td>
    <td>1 Gb</td>
  </tr>
  <tr>
    <td>Architecture</td>
    <td>armv5tel / softfloat</td>
    <td>armv7a / hardfloat</td>
    <td>armv7a / hardfloat</td>
  </tr>
  <tr>
    <td>Disk</td>
    <td>Samsung 250 GB 2.5"</td>
    <td>Hitachi 500 GB 2.5"</td>
    <td>Kingston 60 GB SSD</td>
  </tr>
  <tr>
    <td>Linux kernel</td>
    <td>2.6.33</td>
    <td>3.4.39</td>
    <td>3.4.103</td>
  </tr>
  <tr>
    <td>Bogomips</td>
    <td>149 x 1</td>
    <td>1436 x 2</td>
    <td>1920 x 4</td>
  </tr>
</table>
</p>

### Notes and next env

When I see my software running great on this hardware environment I will move to Amazon EC2 for testing. I want to make sure that `scalesmall` runs on a diverse set of hardwares. Utilizing heterogenous hardware environment is an important goal for me for a number of reasons:

- some organizations continuously buy hardware and it is not feasible to buy the same boxes every year because the boxes get faster and more sophisticated
- other places use virtualized boxes that has different capacities or the allocated capacity differs
- others may want to start a business on EC2 and slowly grow out by adding own colocated boxes to the mix
- I am personally interested in the Arm boards, which get better every year. If I want to build a cluster with these I need to prepare for a heterogenous environment. Also because some manufacturers go bust: Hawkboard, Pandaboard, Plug computers, ...

### Episodes

1. [Ideas to experiment with](/Scalesmall-Experiment-Begins/)
2. [More ideas and a first protocol that is not in use anymore](/Scalesmall-W1-Combininig-Events/)
3. [Got rid of the original protocol and looking into CRDTs](/Scalesmall-W2-First-Redesign/)
4. [My first ramblings about function guards](/Scalesmall-W3-Elixir-Macro-Guards/)
5. [The group membership messages](/Scalesmall-W4-Message-Contents-Finalized/)
6. [Design of a mixed broadcast](/Scalesmall-W5-UDP-Multicast-Mixed-With-TCP/)
7. [My ARM based testbed](/Scalesmall-W6-W7-Test-environment/)
8. [Experience with defstruct, defrecord and ETS](/Scalesmall-W8-W10-Elixir-Tuples-Maps-and-ETS/)
