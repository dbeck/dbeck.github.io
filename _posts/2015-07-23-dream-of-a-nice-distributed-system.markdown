---
published: false
layout: post
category: Other
tags:
  - elixir
  - distributed
desc: Dream of a nice distributed system in Elixir
description: Dream of a nice distributed system in Elixir
keywords: "Erlang, Elixir, Distributed, Portable Native Client"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/elixirpexe.png
pageid: elixirpexe
---

A bit of my history around Ruby and C++, and my future could be Elixir?

### Ruby
I don’t want to be rational here. I just fell in love with Elixir. I had the same feeling with Ruby at first. I created a website with Rails and enjoyed how much nicer and easier was compared to the older methods. Then my love disappeared when I tried this in a very different scenario. I started writing a distributed filesystem in Ruby for my own entertainment. I worked full time on a distributed filesystem in my pro life and wanted to try a more enjoyable alternative.

Ruby was a big disappontment there. I knew it is going to be slow just didn’t expect how slow it became. The other disappointment was the threading model. The whole project ended up wrestling for squeezing out a bit of performance to arrive to a somewhat acceptable range.

### C++
Before and after this Ruby experience I spent all my career writing programs in C++. This is my preferred programming language because I know it and I am productive in C++. When C++11 and co. came out I was very excited and still am excited, BTW. I started using all the great new features like the new threading primitives and most notably I used more and more Lambda expressions. Finally I found myself that I do rapid prototyping with Lambdas and then I tend to reorganize the code I have written in classes because that is what I am used to.

### Elixir
This was the point when I heard about Elixir and I was fortunate enough to have the time to read the [Elixir book](https://pragprog.com/book/elixir/programming-elixir). Than everything clicked in. I realized that I should have written things in a functional language since ages.

I did try Erlang few years ago because I read the nice features of the Erlang VM and I saw how useful these would be in the distributed systems I worked on. The Erlang language on the other hand was not to my taste. I could write programs in it but I didn’t enjoy it. It was also well before my Lambda experiences so I didn’t feel the need to struggle with Erlang.

### Portable Native Client
So now I am deeply in love with Elixir but as with other relations I am affraid to jump in full heartedly because of previous frustrations. My main fear is that I am going to invest a lot and at some point it is going to be slow. Or too slow for the actual task I want to use it for. Then I will have to find workarounds to achieve an acceptable level of performance.

Few weeks ago I met the [Portable Native Client](https://www.chromium.org/nativeclient/pnacl/introduction-to-portable-native-client) solution that is used in the Google Chrome browser. This allows someone to write code in C++ which will be compiled to an intermediate format. This intermediate format is still platform independent. This format can be distributed to other machines and they can run it by first translating to their architecture and then pasing this into a secured execution environment. The translation can be either fast or optimized. According to the Google publications the code after the optimized translation is around 5–10% slower than if the same code would have been natively compiled from C++. This is fine for me.

### Idea
Putting these altogether. Let’s suppose I want to write a distributed system that builds on runtime code upgrades feature on the Erlang VM and also want to distribute processing tasks across Erlang nodes. With Portable Native Client I have an additional option: I can write these processig tasks in C++ and send them over the network. Suppose I have a mixed system that has ARM, MIPS and X86/64 machines I can still do that it with Portable Native Executables because the translator can spit native code for these platforms.

The distributed system I am designing should process large amount of data in a cluster while the processing steps should be dynamic. For example the user may want to add a processing step downloaded from our web application store. He just need to download it and pass it to our Elixir based system which decides where to run it. May be on a NAS or a Phone or and IoT device?

In any case this should be scalable, load balanced, cloud ready, fast and secure. With this tools in place it is a lot easier. Oh yes, I forgot to mention that the [Portable Native Client](https://www.chromium.org/nativeclient/pnacl/introduction-to-portable-native-client) is heavliy guarded, which would save me a lot of headache on the security front.

![Elixir and Portable Native Client](/images/elixirpexe.png "Elixir with Portable Native Client")

