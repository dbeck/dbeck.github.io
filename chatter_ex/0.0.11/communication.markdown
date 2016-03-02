---
published: true
layout: default
category: "Chatter for Elixir"
tags:
  - elixir
  - scalesmall
  - chatter
  - gossip
desc: Chatter Communication Internals (0.0.11)
description: Chatter Communication Internals (0.0.11)
keywords: "Elixir, Distributed, Erlang, Scalable, Multicast, Broadcast, Gossip"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/chatter_message_structure.png
woopra: chatterex_communication_v0_0_11
scalesmall_subscribe: false
---

# Communication Internals (Chatter 0.0.11)

## Message structure

The `Chatter` message structure is designed to be secure and small. Since the NetIDs are central to Chatter, they appear at many places in the message:

- when identifying the sender
- when passing the message distribution list to other nodes
- when telling other nodes, who we received multicast messages from
- (and the GroupManager is also using them at its LocalClock and WorldClock)

Because of this widespread and often redundant usage, I decided to factor out the NetIDs into a `NetID table`. This adds extra complexity at the message encoding and decoding but gives a huge shrink in the message size, both because of the removed redundancy and also because of compression is more efficient.

![structure](/images/chatter_message_structure.png)

## Overview

Chatter uses a TCP based unicast for spreading the messages. However it has a few twists on that. The first is a logarithmic message distribution that I described in a few other posts too: I started thinking about logarithmic TCP broadcast in [this](/Scalesmall-Experiment-Begins/) and [this](/Scalesmall-W5-UDP-Multicast-Mixed-With-TCP/) posts.

## Logarithmic TCP broadcast recap

The ideas is to share the burden of transmitting data between nodes. Every time I broadcast to others I do this:

1. I contact one node on TCP and pass the message to be sent and half of the destinations I need to send to. The node who receives this message and destination list must start the same gossip procedure.
2. In the next turn I pick one node from the remaining destination set and repeat at step #1.

I keep repeating until the destination set is empty.

![Logarithmic broadcast](/images/log_broadcast.png)

The goal is to reduce the number of sends N1 does at the expense of a slightly larger messages. The `Gossip` message holds the extra data plus the original message payload.

## UDP multicast optimization

`Chatter` saves the `Seen ID list` for every message it receives. Based on that it knows if other peers claim that they have received UDP multicast messages from the given node. If this indicates that the destination does receive multicast from us, then we are free to use it instead of TCP. We both would benefit since the peer will have the information sooner and the delivery is less work for us.

`Chatter` replaces the `Seen ID list` and the `BroadcastID` on every packet it forwards to the information corresponds to the given node.

To illustrate how it works, let's compare the two images below. The first shows the TCP only logarithmic broadcast. It involves more and more nodes in the communication at every round.

![TCP Only](/images/tcp_broadcast.png)

Let's suppose the nodes reside on two subnets, A and B. The multicast messages don't travel between these given subnets, thus some nodes can be removed from the TCP distribution list, but not all.

![mixed](/images/mixed_broadcast1.png)

Subnet A receive the message right away through multicast, and subnet B receives it at the second round. Subnet B receives it twice more because the second and third TCP targets will send multicast messages again while eliminating the TCP targets. If the initiator would be smarter, subnet B would receive less traffic. This optimization is yet to be developed.

The end result is that both subnets receive less traffic and the message spread faster by the multicast optimization.

## Not all nodes are eliminated

The first step at every broadcast is that `Chatter` sends out the message on multicast unconditionally. Then it checks the destination lists and removes those nodes that should have received the message on multicast at the first step. The remaining nodes will be contacted by the logarithmic TCP broadcast.

It has a high chance that every node on the local network will be removed from the distribution list, sooner or later. Since UDP is not reliable this would mean that we base all communication on an unreliable channel for the local network, which is not desirable. For that reason, `Chatter` always keeps a random node of the original distribution list, no matter what the UDP `Seen IDs list` says, and this random node will be contacted on TCP too.

## Messages duplicated, multiplicated

It is very likely that messages will be delivered multiple times to nodes, so the application need to handle that. `GroupManager` actually benefit from this because the `MessageHandler`'s `dispatch` callback works in a special way. It not just receives an object but can return a different object of the same type. This result object will be included in the next message transfer round and allows the application to merge in changes or additional information while the gossip progresses.


# Other docs

- [Intro blog post about Chatter](/Chatter-extracted-from-ScaleSmall/)
- [Quickstart Guide](quickstart.html)
- [Overview](index.html)
- [FAQ](faq.html)

