---
published: true
layout: post
category: Elixir
tags: 
  - elixir
  - distributed
  - scalesmall
desc: ScaleSmall Experiment Begins
description: ScaleSmall Experiment Begins
keywords: "Elixir, Distributed, Erlang, Consistent hashing, Riak-Core, Dynamo, Replicated state machine, Kafka, Scalable"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/P8142409.JPG
woopra: scalesmall1
scalesmall_subscribe: true
twitter_embed: true
---

This is a beginning of a new Elixir experiment series. I want to play with a distributed, scalable small-message server. I firmly believe that it should be possible to reach an average of 1M small messages per server in a fault tolerant distributed setup with typical commodity hardware. Well, this means nothing, unless I tell what guarantees this system provides, constraints, etc...

The good thing is that it is an experiment. I only want to play around and share my thoughts, I don't want to plan too much ahead. My only goal is to keep my eyes open and see what I find, and try to be as unbiased as possible. This alone is not an easy task for a hardcore C++ programmer.

If you look closely you may find similarities to [riak](http://docs.basho.com/riak/latest/) and [Dynamo](http://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf).

**I want a system where**:

- nodes can join and leave dynamically
- no master election
- gossip based communication

**The parts I want to experiment with**:

- dynamic consistent hashing
- separate load balancing and resource location
- combine [Merkle tree](https://en.wikipedia.org/wiki/Merkle_tree) and [vector clock](https://en.wikipedia.org/wiki/Vector_clock)
- support non uniform nodes
- logarithmic broadcast in the gossip protocol
- greedy resource usage
- client controlled consistency
- lazy replicated state machine

![pic](/images/P8142409.JPG)

### Consistent hashing and non-uniform nodes

In some systems these two concerns are inter mixed:

1. how to distribute load (or allocate resources) more or less evenly across nodes
2. how to locate previously allocated resources

The first one decides where we want to put new data or load. The second one tells where to find it.

I understand that binding these things together simplifies the design. The problems is, it assumes that if Keys are mapped evenly across the key range to nodes/partitions, then the resource usage at each node/partition will be approximately the same. May be yes, as long as the resource usage corresponding to the Keys don't vary too much.

If resource usages are not evenly distributed across the Key range then we easily end up having some nodes full and others lightly loaded. To resolve this I am thinking about a dynamic mapping between nodes and key ranges, so it can change over time.

The dynamic mapping could make it easy to support non-uniform nodes. This could be a win by itself.

### Replicated state machine

I am a big fan of state machines. I like modelling processes with them. When I first met the idea of keeping consistent state across nodes by replaying the same events, at the same order on every node, made a lot of sense to me. Now, we only need to figure how to ensure that the sequence of events are the same at every node.

Paxos and Raft are popular for solving the problem.

There is a twist though. I want to use a state machine for handling node states, joins and leaves. The events are Join(Node) and Leave(Node). If we distribute these events in the same order then all nodes will have the same idea about who is in and who has left the group. 

My particular case has a few interesting properties. If a node joins and leaves the group immediately then we can merge the two events, may be even omit them? The other thing is the node events are independent of each other so they can be merged. For example one node detects that NodeA left and another node detects NodeB left, then these events can be merged. So I could allow the nodes to either see a different sequence of events or transform the event sequence to an equivalent other one.

This reminds me the blockchain where people send transactions and these gets merged into a new block by the miners. In the blockchain there is no leader election but participants can still agree on a ledger which is the same at every node.

I want to play around with a model similar to blockchain.

### Combine Merkle Tree and Vector Clock

The purpose of [Vector Clock](https://en.wikipedia.org/wiki/Vector_clock) is to reason about causality. Blockchain reaches an agreement about events with the help of [Merkle Trees](https://en.wikipedia.org/wiki/Merkle_tree). I was wondering how cool it would be to create a vector clock that ticks hashes. It would distribute the hash of the node's view about the shared state, rather than a single counter. States would be represented in a Merkle Tree and the actual state would be represented by the actual hash value of the tree.

**Example state tree would be**:

```
version: hash:
-------- --------------------------------------
     00: b026324c6904b2a9cb4b88d6d61c81d1 ->
     01: 26ab0db90d72e28ad0ba1e22ee510510 ->
     02: 6d7fce9fee471194aa8b5b6e47267f03 ->
     03: 48a24b70a0b376535542b996af517398 ->
fork:  03A: 9ae0ea9e3c9c6e1b9b6252c8395efdc1 ->
     04: 1dcca23355272056f04fe8bf20edfce0 ->
fork:  04A: 31d30eea8d0968d6458e0ad0027c9f80 ->
     05: 7c5aba41f53293b712fd86d08ed5b36e ->
```

**So the Vector Clock would be like**:

```
node:    hash:                              version:
------   --------------------------------   ------------
NodeA:   1dcca23355272056f04fe8bf20edfce0   // @ 04
NodeB:   1dcca23355272056f04fe8bf20edfce0   // @ 04
NodeC:   1dcca23355272056f04fe8bf20edfce0   // @ 04
NodeD:   1dcca23355272056f04fe8bf20edfce0   // @ 04
NodeE:   31d30eea8d0968d6458e0ad0027c9f80   // @ 04A fork
NodeF:   31d30eea8d0968d6458e0ad0027c9f80   // @ 04A fork
NodeG:   7c5aba41f53293b712fd86d08ed5b36e   // @ 05
NodeH:   7c5aba41f53293b712fd86d08ed5b36e   // @ 05
NodeI:   7c5aba41f53293b712fd86d08ed5b36e   // @ 05
NodeJ:   7c5aba41f53293b712fd86d08ed5b36e   // @ 05
```

This would simplify reconciliation because we would exactly know where did a node depart from the others state.

### Greedy resource usage

When I buy a server and I run it in a data center, my costs don't depend on some of the resources I use on this server. For instance if the storage in the box is only 20% full, than I wasted 80% of both operational and capital expenses I spent on the storage. Same applies to RAM.

CPU may be different if high CPU usage translates to higher electricity bills, so it may impact operational expenses, but under utilized CPU smells lost money on the capital expenses front.

This observation leads me to a design where I try to utilize as much of the memory and hard drive as possible.

### Logarithmic broadcast

Let's suppose I have a message M that N1 want's to distribute to 7 other Nodes: N2-N8. Then I could come up with a distribution tree like this:

```
Round1: N1 (M) -> N2
Round2: N1 (M) -> N3, N2 (M) -> N4
Round3: N1 (M) -> N5, N2 (M) -> N6, N3 (M) -> N7, N4 (M) -> N8
```

The idea is when N1 sends the M message to N2 it would pass along a list of nodes that N2 is supposed to forward M to. N2 would do the same, when it sends M to N4.

The algorithm would be simple. When N1 has the list of nodes, in each round it would half the node list and pass the remainder to a new node.

On top of this, each node would randomize its list, so a new broadcast would build a different tree.

### Client controlled consistency and fault tolerance

Different users and use-cases have different consistency requirements. Let's imagine this message flow:

- messages are stored in memory first
- then the messages get compressed
- the compressed message is forwarded to other nodes
- and the compressed message is stored to disk

I think the guarantees a client want could be very different, depending on the use case. It may want strong guarantees and wait for the message to be stored at least 3 node's disk. Or it is sufficient to have 1 disk and 1 memory copy or just one memory copy, etc...

The point is that I want to delegate this decision to the client who sends the data on a per session bases rather then making this as a system wide parameter.

A first sketch of this protocol is available [here](/Experimental-Reliable-Small-Message-Protocol/).

### Github repo

I started a new MIT licensed project for this experiment at [github](https://github.com/dbeck/scalesmall).

The first I want to implement is the facility that allows nodes join and leave the group dynamically. This will be implemented in the [group_manager application](https://github.com/dbeck/scalesmall/tree/master/apps/group_manager).

### Episodes

- [First episode](/Scalesmall-Experiment-Begins/) started with lots of ideas
- [The second episode](/Scalesmall-W1-Combininig-Events/) continued with more ideas and the now obsolete protocol
- [The third episode](/Scalesmall-W2-First-Redesign/) is about getting rid of bad ideas and diving into CRDTs
- [The fourth episode](/Scalesmall-W3-Elixir-Macro-Guards/) is detour at the lands of function guard macros
- [The fifth episode](/Scalesmall-W4-Message-Contents-Finalized/) finalized the message contents
- [The sixth episode](/Scalesmall-W5-UDP-Multicast-Mixed-With-TCP/) is a tour on the UDP multicast and TCP land

### Update: 2015-12-27

It's been over 5 weeks since I have written the original post. During these weeks I worked a lot on the ideas above, spent time on better understanding the concepts and try out some of these. The results are mixed:

- **Logarithmic broadcast**: is the thing I currently work on, but I want to mix it with UDP multicast ([more on this](/Scalesmall-W5-UDP-Multicast-Mixed-With-TCP/))
- **Client controlled consistency and fault tolerance** and **Greedy resource usage**: still on the plate and when I completed the group membership part I will focus on this
- **Combine Merkle Tree and Vector Clock**: I no longer fancy this idea. I turned to Idempotent, Commutative, Associative datatypes instead.
- **Non-uniform nodes**: the group membership messages are to solve this problem

Two days ago Sean Cribbs (@seancribbs) had a valid comment on twitter about `Combine Merkle Tree and Vector Clock`:

<blockquote class="twitter-tweet" lang="hu"><p lang="en" dir="ltr"><a href="https://twitter.com/SeanTAllen">@SeanTAllen</a> <a href="https://twitter.com/marick">@marick</a> <a href="https://twitter.com/dbeck74">@dbeck74</a> I don&#39;t follow how Merkle trees and vector clocks can become one thing</p>&mdash; 5 golden chash rings (@seancribbs) <a href="https://twitter.com/seancribbs/status/680541321266761729">2015. december 26.</a></blockquote> 

Which led to further messages on twitter:

<blockquote class="twitter-tweet" lang="hu"><p lang="en" dir="ltr"><a href="https://twitter.com/dbeck74">@dbeck74</a> <a href="https://twitter.com/SeanTAllen">@SeanTAllen</a> <a href="https://twitter.com/marick">@marick</a> I could see how Merkle could help in finding gaps in a causal history but they aren&#39;t more compact than VCs</p>&mdash; 5 golden chash rings (@seancribbs) <a href="https://twitter.com/seancribbs/status/680775122978869248">2015. december 26.</a></blockquote>

And these:

<blockquote class="twitter-tweet" lang="hu"><p lang="en" dir="ltr"><a href="https://twitter.com/dbeck74">@dbeck74</a> <a href="https://twitter.com/SeanTAllen">@SeanTAllen</a> <a href="https://twitter.com/marick">@marick</a> for instance, if you have a static topology you can remove the ids and just have a list of ints</p>&mdash; 5 golden chash rings (@seancribbs) <a href="https://twitter.com/seancribbs/status/680775427586011136">2015. december 26.</a></blockquote>

I fully agree with Sean, passing hash values is not more compact than Vector Clocks and VC with static topology can omit the node id, which further cuts their size.

The original idea was bad, I cannot defend that. In the next episodes I used a more vector clock like solution in my experiments. There is one bit that comes back to me from time to time:

- do I really care about causality or may be what I am interested in is the state across nodes?
- if it is state, why don't I represent the state with hashes?

Edge cases, that may not happen in every system:

- **1)** a shared value is flipping back and forth: `A=1 -> A=2 -> A=1 ...`
- **2)** a shared datatype and its single operation is Commutative and Associative and receives parallel updates that can be combined in different order. this would result in different histories but the same results

I feel it should be possible to omit the intermediate states with the help of hashes, but I haven't spent much time with this.
