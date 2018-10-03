---
published: true
layout: post
category: "ScaleSmall for Elixir"
tags:
  - elixir
  - distributed
  - scalesmall
desc: ScaleSmall Experiment Week Four / Data Lib Completed
description: ScaleSmall Experiment Week Four / Data Lib Completed
keywords: "Elixir, Distributed, Erlang, Macro, High-performance, Scalable, CRDT, VectorClock"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/P8142435.JPG
pageid: scalesmallw4
scalesmall_subscribe: false
---

This week I further clarified what I want from the group membership messages and also implemented them. I added [unit tests](https://github.com/dbeck/scalesmall/tree/w4/apps/group_manager/test/group_manager/data) for all functions, so I feel more or less safe to continue with the network communication part next week.

I am seriously considering to add property based tests as well. Only that I don't have the experience in this, so this will need to wait a bit. (With so much time spent on the theory I am getting eager to see my stuff to do something useful.)

![hello from Glasgow](/images/P8142435.JPG)

### Requirements

I decided that in `scalesmall` the only one who makes a decision about the group membership and its participation in the shared work is the node itself. Thus only the given node `writes` the shared information about its participation and everyone else are `readers`.

This means that I only need to make sure that:

- whenever the node wants to notify the group about its decision, it eventually reaches all interested parties
- when the messages eventually arrive, the recipients must be able to correctly combine them which boils down to:
  - these messages be idempotent: `A + A = A`, so they may be delivered multiple times
  - the messages be commutative: `A + B = B + A` and associative `A + (B + C) = (A + B) + C`, so they can be delivered and applied to the shared state in any order

Using a `Last-Write-Wins` strategy this seems to be super easy, if I just add a `client clock` to the messages.

### Clocks

Digging through the literature, there seem to be a wealth of clocks like version vectors with client and server side update counters and also there are the novel 'dot clocks'. When I read the papers about them I was tempted to use what is newest and shinier until I realized what suits me best.

On a sidenote: I find very little literature or blog posts give a good overview about when to use which and why. People seem to focus on their results and talk about that specific niche only. If you happen to be wandering in the land of these clocks I suggest to read [Scalable and Accurate Causality Tracking for Eventually Consistent Stores](/images/dvvset-dais.pdf) by Paulo Sérgio Almeida, Carlos Baquero, Ricardo Gonçalves, Nuno Preguiça, and Victor Fonte.

Reading the paper I realized that my use case could be covered with a very simple solution. The nodes need to increment and pass a counter at each state change and send this over. This is very much like the VVclient approach in the paper.

### Local Clock Module

[GroupManager.Data.LocalClock](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/lib/group_manager/data/local_clock.ex) represents the counter that is going to be attached to the information the node sends over. Only the given node is supposed to change the clock value. Everyone else are reading it.

[LocalClock tests can be found here.](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/test/group_manager/data/local_clock_test.exs)

### Item Module

If you haven't read the previous posts in the series: I treat groups as a 32bit unsigned integer range from 0 to 0xffffffffff. The incoming requests are mapped to an integer in this range. The nodes decide what part of the range they want to serve and publish this information. Whenever they decide to serve an additional (sub)range or they want to stop serving a subrange they publish this information to the group. The [GorupManager.Data.Item](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/lib/group_manager/data/item.ex) represents this information. It has:

- `member`: identifies the node
- `op`: is either :add or :rmv
- `start_range`
- `end_range`
- `priority`

The priority is a hint that comes into the picture when multiple nodes are serving the same range. This information is opaque from the group membership stand point. Nodes can use it to decide the order in which they participate in a workload. The idea is that `scalesmall` should be able to support heterogenous nodes. The priority field could help in distinguishing between more or less reliable machines, different capacities and better or worst network connectivity.

[Item tests can be found here.](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/test/group_manager/data/item_test.exs)

### TimedItem Module

![timed_item](/images/timed_item.png)

The [GroupManager.Data.TimedItem](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/lib/group_manager/data/timed_item.ex) module represents and `Item` at a given `LocalClock`. This binding allows us to pick the last write of the given nodes. Items are treated as same when these fields match:

- `member`
- `start_range`
- `end_range`

The `op` and `priority` fields will be overwritten by the last write.

[TimedItem tests can be found here.](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/test/group_manager/data/timed_item_test.exs)

### TimedSet Module

The [GroupManager.Data.TimedSet](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/lib/group_manager/data/timed_set.ex) module is a list of `TimedItems` and only used for convenience. Its main use is to validate TimedItem members when added to the list.

[TimedSet tests can be found here.](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/test/group_manager/data/timed_set_test.exs)

### WorldClock Module

The [GroupManager.Data.WorldClock](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/lib/group_manager/data/world_clock.ex) module is a list of `LocalClock` items. It both validates `the LocalClock` members when added and also overwrites the older LocalClock for the given member if present. `WorldClock` is not used in comparisons. Its purpose is to tell nodes if they lag behind on updates from a given node. When this happens they should take action to gather the missing pieces either from the origin node itself or from the other nodes.

[WorldClock tests can be found here.](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/test/group_manager/data/world_clock_test.exs)

### Message Module

![message](/images/message.png)

The [GroupManager.Data.Message](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/lib/group_manager/data/message.ex) is the topmost module of the `Data` lib hierarchy. It has a `WorldClock` and a `TimedSet`. The `WorldClock` gets updated when new `TimedItem` elements are added to the `Message`.

[Message tests can be found here.](https://github.com/dbeck/scalesmall/blob/w4/apps/group_manager/test/group_manager/data/message_test.exs)

### Episodes

1. [Ideas to experiment with](/Scalesmall-Experiment-Begins/)
2. [More ideas and a first protocol that is not in use anymore](/Scalesmall-W1-Combininig-Events/)
3. [Got rid of the original protocol and looking into CRDTs](/Scalesmall-W2-First-Redesign/)
4. [My first ramblings about function guards](/Scalesmall-W3-Elixir-Macro-Guards/)
5. [The group membership messages](/Scalesmall-W4-Message-Contents-Finalized/)
6. [Design of a mixed broadcast](/Scalesmall-W5-UDP-Multicast-Mixed-With-TCP/)
7. [My ARM based testbed](/Scalesmall-W6-W7-Test-environment/)
8. [Experience with defstruct, defrecord and ETS](/Scalesmall-W8-W10-Elixir-Tuples-Maps-and-ETS/)
9. [GroupManager code works, beta](/Scalesmall-W11-W13-Group-Manager-Implementation/)
10. [GroupManager more information and improvements](/Scalesmall-W14-More-Group-Manager-Information/)
