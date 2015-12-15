---
published: true
layout: post
category: Elixir
tags: 
  - elixir
  - distributed
  - scalesmall
  - CRDT
desc: ScaleSmall Experiment Week Two / First Redesign w/ CRDTs
keywords: "Elixir, Distributed, Erlang, Testing, High-performance, Scalable, CRDT"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF5761.JPG
woopra: scalesmallw2
scalesmall_subscribe: true
---

This week I made progress by getting rid of bad ideas. I started implementing the messaging part. The message definitions and their operations. While doing that I had the feeling that something is wrong with the basics, just didn't know what. On a separate thread I was watching the conference presentations of [Strangeloop 2015](http://www.thestrangeloop.com/2015/sessions.html) and found ["Distributed, Eventually Consistent Computations" by Christopher Meiklejohn](https://www.youtube.com/watch?v=lsKaNDj4TrE) and ["Building Scalable Stateful Services" by Caitie McCaffrey](https://www.youtube.com/watch?v=H0i_bXKwujQ).

Very influential talks that reinforced my feeling that I need to go back designing the shared state of ```scalesmall``` and the messaging. Let's see why.

(It is worth having a look at the other videos of [StrangeLoop 2015](http://www.thestrangeloop.com/2015/sessions.html). They are great.)

![CRDT](/images/DSCF5761.JPG)

### CRDTs

The StrangeLoop talks made me interested in CRDTs. I watched few more talks like:

- [(Highly suggested) Marc Shapiro the inventor of CRDTs gives a very clear and enlightening presentation](https://www.youtube.com/watch?v=ebWVLVhiaiY)
- [Jeremy Ong: CRDTs in Production](https://www.youtube.com/watch?v=PdCZXLEh788)
- [Alexander Songe: CRDT: Datatype for the Apocalypse](https://www.youtube.com/watch?v=txD1tfyIIvY)


Here is a sentence from the Soundcloud's developer blog ( [about Roshi](https://developers.soundcloud.com/blog/roshi-a-crdt-system-for-timestamped-events) ):

> The tl;dr on CRDTs is that by constraining your operations to only those which are associative, commutative, and idempotent, you sidestep a lot of the complexity in distributed programming.

Equipped with all these information I realized that:

- what I wanted to do with my protocol is already an existing idea
- my messages as I designed them wont't achieve this goal

### The aim

This is what I want to achieve with the messages:

- I want nodes to agree on a shared state
- the nodes don't do agreement conversations when their information is complementary
- when the nodes need to agree, that should be done automatically by rules
- the state consists of key ranges that the nodes serve
- the shared state can be lazily distributed and to be consistent eventually
- the nodes to be able to tighten their range(s) when they are getting full

[Originally I thought](/Scalesmall-W1-Combininig-Events/) that sending these messages would make this happen:

- agreeing what the subranges are by ```Split```-ing the subranges
- start and stop serving a subrange (```Register``` and  ```Release```)
- agreeing the priority list for a subrange (```Promote``` and ```Demote```)

Now I think differently because the subrange ```Split``` intermixes very badly with the other messages. It makes a big difference to ```Split``` a subrange and then nodes ```Register``` for the subrange or first ```Register``` and then ```Split```. The same applies to ```Split``` and ```Promote```/```Demote```. On top of all these ```Promote``` and ```Demote``` are not Idempotent. 

### The new protocol

I no longer want to split the range explicitly and don't want to maintain the split points as an explicit information. This can be calculated if the nodes send these messages:

- ```Register( node_id, start_range, end_range )```
- ```Release( node_id, start_range, end_range )```

The good thing with this approach is that this messaging can be easily represented by a CRDT set when the elements in the set is the ```(node_id, start_range, end_range)``` triple. ```Register``` and ```Release``` are the add and remove operations to the set. There are a lot of CRDT set types, differing on the conflict resolution, operation vs state based, delta or full message based. At the moment I favor [AWORSet](https://github.com/asonge/loom/blob/master/lib/loom/aworset.ex) more than others, but I need to experiment with this.

The other part of the protocol is to be able to assign a priority to a node for a given subrange. Originally the ```Promote``` and ```Demote``` messages served this purpose, but now I believe that a ```PN-Counter``` per subrange would be better. In fact a map between subranges to integer values would be great. Fortunately the [AWORMap](https://github.com/asonge/loom/blob/master/lib/loom/awormap.ex) does exactly that.

With this CRDT map my API can be reduced to these operations:

- ```Increase( node_id, start_range, end_range, value )```
- ```Decrease( node_id, start_range, end_range, value )```

The ```Increase``` operation would be an implicit ```add``` if the (node_id, start_range, end_range) triple is not yet in the map. When the priority ```value``` goes down to zero it would be an implicit ```Release```.

### Use loom?

It turns out that much of my needs in terms of shared state is handled by the [loom library](https://github.com/asonge/loom). I only need to add a distribution protocol to that. I will definitely give it a try.

The other option would be to write a similar thing on my own. I believe there are a few interesting properties about my case:

- information about a subrange is not equally important to nodes
- tho ones who actually participate are more interested in changes than others
- I need to check how much history a node keeps about the map
- the nodes who don't participate in a subrange may not want to keep too much history about it

### Episodes

- [First episode](/Scalesmall-Experiment-Begins/) started with lots of ideas
- [The second episode](/Scalesmall-W1-Combininig-Events/) continued with more ideas and the now obsolete protocol
- [The third episode](/Scalesmall-W2-First-Redesign/) is about getting rid of bad ideas and diving into CRDTs
- [The fourth episode](/Scalesmall-W3-Elixir-Macro-Guards/) is detour at the lands of function guard macros
- [The fifth episode](/Scalesmall-W4-Message-Contents-Finalized/) finalized the message contents
