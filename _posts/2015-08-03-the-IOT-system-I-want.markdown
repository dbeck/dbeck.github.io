---
published: true
layout: post
category: IoT
tags: 
  - IoT
  - ecosystem
  - sheevaplug
  - igep
desc: The IOT system I want
keywords: "IOT, Ecosystem, EndUser"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/iot2.jpg
woopra: iotiwant
---

I have mixed feelings when I hear the term IoT. Partly because as a developer and startupper I have a different viewpoint of IoT than I have when I am a customer. My developer part is more like a hacker with interest all the devices around me. The consumer part don't really want to spend time with these thingies only benefit from them. The startupper wants to do business.

In this post I will give a bit of my IoT hacking history and write about my present.

### Linksys router
It was more than 10 years ago. Someone in the neighborhood has hacked my Linksys WRT54G router. My bandwidth was not so high so it was easy to notice the slowdown. I did a bit of research and realized that I can replace the firmware with a custom Tomato one. This was a very easy move, but in my case this broke a mental barrier. I realized that the things around me can be changed and customized.

### HP Ipaq
My next victim was my HP Ipaq. This was a small tablet like device, with a very weak hardware and a badly responding touch screen. I had no big plans with replacing the factory OS with Angstrom Linux, I just wanted to see that it is possible and check. The Linux did start and I could do very simple tasks, however the whole experiment was pointless because of the hardware was so limited.

### Sheevaplug
It was in 2009. I can't remember how I got to know Sheevaplug. Those days I was working for HP and I already decided to leave the company. I knew that I will have to return my company laptop. My home computer was old because I didn't need to invest into that for almost 10 years.

So I was looking for an option. I was pretty much pissed off by the noisy computers and I wanted something small and quiet. I believe this was the main motivation.

Sheevaplug is a very small ARM based computer with a single ethernet and two USB connectors. A fairly fast 1 GHZ CPU and good amount of RAM. I was up to an experiment to use this as a desktop computer by plugging a USB hub in and use USB display adapter,  keyboard and mouse.

This worked for some time, but I realized that the USB devices are not as reliable as I wanted.

### IGEP Desktop
After I spent a few month playing with SheevaPlug I realized that I want something better.  This was in 2010. I got to know BeagleBoard which was almost good for my purposes except the versions available those days didn't have Ethernet. Then I found IGEP V2 which had the same Texas Instruments OMAP ARM CPU and it also had Ethernet, HDMI and USB.

After a bit of experimenting and hacking this device served as my desktop for a year. I liked those days.

### Hawkboard experiments
In the same year, 2010 I noticed another board: the HawkBoard. It has less ram, slower CPU but had a SATA connector. I bought three of them, because I wanted to experiment with a distributed filesystem. The board was build on the Texas Instruments OMAP L138 platform which bundles a DSP (Digital Signal Processor) with the CPU. 

My idea was to utilize the DSP for streaming data processing such as compression, ECC, may be analytics. That would have been a great fit. 

### My kid has born
When my first daughter has born I happily thrown away all my midnight projects. I bought a quiet X86 PC and all these gizmos and things went to the storage room.

What is very interesting to see how much my mentality has changed with respect to these _things_. Before I didn't mind spending nights hacking these devices, now I only want them to work.

### Me as a consumer
When I think about IoT devices I include the ones I mentioned and more in my picture. I didn't mention my smart TV, mobile phone, tablets and all the _things_ I have. I don't yet have sensors and controllers, intelligent fridge, central heating and such things. As it stands it is not likely that I'll invest in those because I am a consumer. I don't want to spend time configuring these and hacking them in any ways.

### The definition of the things in the IoT
When I first heard this IoT term I didn't understand what is this about. The term doesn't describe it very well. The _Internet_ part suggests that it is about connecting _things_. Which may be OK, but the story doesn't stop there. We actually want _things_ to understand each other. I also want to control _things_. I may want information from these _things_. 

Almost all my friends has _things_ in their homes. A common one is Raspberry PI. Not so many articles mention this device in the IoT literature even though this is a smart one. Many people automate the process of downloading films from the Internet. Fetch subtitles for them. Organize TV series into folders. Make sure no one to miss an episode.

Is Raspberry PI a _thing_ in IoT? I would argue it is. It is intelligent and connected. It does things for us. The only problem with that is a Raspberry PI doesn't need vendors to push down so called _standards_ on our throat. Neither it needs any startups or big company's assistance to operate. Thus it is pretty much ignored.

### Ecosystem
I believe the biggest issue with IoT is the ecosystem. Companies try to carve as huge chunks as possible from the market without actually checking what a customer would want. History repeats itself. I remember a big company had a popular OS and office suite that did all measures to invent standards and technologies to tie/bind people to their ecosystem. (Then Linux and the Open Source movement pretty much killed this.)

There are good examples too. Google's and Apple's app stores are good ones. I imagine an IoT app store where people can share pieces of codes and download them on their _things_. This would encourage standalone developers to participate and share their apps.

### IoT app market example
Let's imagine my friend has developed an application on their Raspberry PI that collects data from sensors and drives fire alarms. If he has means to share the app he could probably make money and other users would benefit too.

The (not so big) problem is that another customer may have a different type of smart device. Google with the Android app market has solved this problem. People with very different hardwares are using the same apps. It is secure and win-win for the developers and the customers too.

I used Android as a cross platform example. I don't really think my friends will install Android on their PIs. 

### Google Portable Native Client to the rescue
Very recently I bumped into Google Native Client which allows users to create applications to be run on different architectures including MIPS, ARM, X86-32 and 64. These happen to cover most tablets, phones, PCs, NAS', Media Boxes and intelligent thingies. 

To make this happen someone needs to setup this app market and create the framework to distribute the apps. Not rocket science.

