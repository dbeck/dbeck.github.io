---
published: true
layout: post
category: "ScaleSmall for Elixir"
tags:
  - elixir
  - scalesmall
  - group-manager
desc: ScaleSmall Experiment Week Eleven to Thirteen / Group Manager now works
description: ScaleSmall Experiment Week Eleven to Thirteen / Group Manager now works
keywords: "Elixir, Distributed, Erlang, Scalable, Group, Manager"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF6871.JPG
woopra: scalesmallw11
scalesmall_subscribe: false
---

This is a major step forward in the `scalesmall` project. The group management code is largely written. The next step is to design and implement what the group is supposed to do.

In this post I will document the achievements and show how to use the `scalesmall` group management code.

**Overview:**

- why
- integrate group manager into a project
- communication between nodes
- group manager messages and data types
- implementation details
- areas to be improved

![OOP](/images/DSCF6871.JPG)

### Why

Why do I need any code for managing a group of nodes in Elixir? The BEAM VM has means for nodes to join each other. It can detect nodes leaving and this is a great foundation for building up a distributed system. Still I have a few ideas and requirements that I want to serve differently:

- what is group membership
- scalability
- multiple groups
- tie information to membership

#### What is group membership

Seems to be an easy question. The group is a set of nodes and membership is being part of the group. This is simple so far. Let's complicate this:

- can a node be a member of multiple groups?
- can a group be a member of another group?

#### Scalability

[This article](http://learnyousomeerlang.com/distribunomicon) gives a good idea of what is possible and what are the limits of BEAM VM distributed architecture support. The TLDR; is that BEAM VM uses a mesh topology which doesn't scale to thousands of nodes. There are ways to circumvent this but none of them seemed to be an easy thing to me.

#### Multiple groups

In `scalesmall` a node can join and leave multiple groups. The rationale behind that is when I have different **machine types** like:

- beefy big box for storing data having lots of RAM for caching
- CUDA node with a few CUDA cards for massive data processing
- avarage box I bought next to the grocery
- Banana PI with a single disk for data backup
- SSD node with a slow CPU and lots of SSDs

Let's define 4 groups based on **roles**:

- RAM cache
- Disk storage
- Backup
- Data processing

Based on these various machine types and roles it would be nice to put them into multiple groups. For example if the CUDA box is idle it can be used to cache data in RAM, or the Banana PI can offer two cores of CPU if the demand for processing power is high.

The other factor is that CPU, Disk, IO Bandwith, Memory speed and capacity, all gets better over new generations of computers but they improve at different pace. So one computer that was great at the data processing role may be not so great there in two years time, but it could still serve as a backup or storage node. So the roles may be rearranged over time when I buy new machines.

#### Tie information to membership

I would like to stretch the definition of group membership, so it is not just about a bool flag about the node being or not being part of a group. In `scalesmall` I want the group members to tell others what they do in the group. Here is how. The task of a group is to serve a key range of 0 to 2^32-1. Each node in the group advertises the:

- subrange(s) they are serving
- and a port where their service is accessible

It is up to the nodes to decide what key ranges they serve. If noone serves a key range then it is not going to be accessible.

There has to be a smart algorithm on the nodes that gathers the topology of the group and based on its capacities decide what part of the key range it wants to serve. (This algorithm is yet to be designed.)

### Integrate GroupManager

```elixir
  # start the group_manager app
  def application do
    [applications: [:logger, :group_manager], mod: {Testme, []}]
  end

  # add scalesmall to deps:
  defp deps do
    [{:scalesmall, git: "https://github.com/dbeck/scalesmall.git", tag: "0.0.4"}]
  end
```

#### Configuration

```elixir
  # in config/config.exs:
  config :group_manager,
    my_addr: System.get_env("GROUP_MANAGER_ADDRESS"),
    my_port: System.get_env("GROUP_MANAGER_PORT") || "29999",
    multicast_addr: System.get_env("GROUP_MANAGER_MULTICAST_ADDRESS") || "224.1.1.1",
    multicast_port: System.get_env("GROUP_MANAGER_MULTICAST_PORT") || "29999",
    multicast_ttl: System.get_env("GROUP_MANAGER_MULTICAST_TTL") || "4"
```

- **my\_addr** and **my\_port**: is the IPv4 address string where the GroupManager binds to (default port is 29999 and my_addr is the defaulted to first address `:inet.getif`returns that has a broadcast address defined [see](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/chatter.ex#L116))
- **multicast\_addr** and **multicast\_port**: is the UDP multicast address
- **multicast_ttl** is how many hops a multicast packet may go throug (default is 4)

#### Usage

**Join a group**:

When I don't know any members of a group or I am the first one in the group I can join the group with only the name of the group. This sends a multicast message on the network so if there are other peers they will know I want to participate. Whenever they send a multicast I will know about all other members.

```elixir
  iex(1)> GroupManager.join("Group1")
  :ok
```

If I explicitly add a list of nodes I want to be notified about my will then I can add them in the list. They will be contacted through TCP through a logarithmic broadcast. More about the various communication methods in the `communication between nodes` section.

```elixir
  iex(2)> alias GroupManager.Chatter.NetID                          
  nil
  iex(3)> GroupManager.join("Group1",[ NetID.new({192,168,1,97}, 29999) ])
  :ok
```

More on the `NetID` type in the `group manager messages and data types` section.

**Query group members**:

```elixir
  iex(4)> GroupManager.members("Group1")                                  
  [{:net_id, {192, 168, 1, 100}, 29999}, {:net_id, {192, 168, 1, 97}, 29999}]
```

This returns a list of `NetID` types which identifies peers. Each node slowly learns about all other groups too, so I don't need to be part of a group to know who the members are. To gather the list of groups I can do this:

```elixir
  iex(5)> GroupManager.groups
  ["Group1"]
```

**Tell others I want to serve a key range**:

```elixir
  iex(6)> GroupManager.add_item("Group1",0xf,0xff,11223)
  {:ok,
    {:timed_item,
      {:item, {:net_id, {192, 168, 1, 100}, 29999}, :add, 15, 255, 11223},
      {:local_clock, {:net_id, {192, 168, 1, 100}, 29999}, 2}}}
```

This tells others that I want to serve the key range from 0xf to 0xff and my service is accessible on port #11223. 

**Query group topology**:

```elixir
  iex(7)> GroupManager.topology("Group1")
  [{:timed_item,
     {:item, {:net_id, {192, 168, 1, 97}, 29999}, :get, 0, 4294967295, 0},
     {:local_clock, {:net_id, {192, 168, 1, 97}, 29999}, 0}},
   {:timed_item,
     {:item, {:net_id, {192, 168, 1, 100}, 29999}, :get, 0, 4294967295, 0},
     {:local_clock, {:net_id, {192, 168, 1, 100}, 29999}, 1}},
   {:timed_item,
     {:item, {:net_id, {192, 168, 1, 100}, 29999}, :add, 15, 255, 11223},
     {:local_clock, {:net_id, {192, 168, 1, 100}, 29999}, 2}}]
```

The topology is a list of `TimedItem` objects, which has a local clock and the topology data. More on `TimedItem`, `Item` and `LocalClock` in the `group manager messages and data types` section.

The above list has `:get` and `:add` items. `:add` represents the participation in the key range and `:get` tells other members, that we are interested in updates about the group topology. If I want to see those who participate in the key range I can:

```elixir
  iex(8)> GroupManager.topology("Group1", :add)
  [{:timed_item,
    {:item, {:net_id, {192, 168, 1, 100}, 29999}, :add, 15, 255, 11223},
    {:local_clock, {:net_id, {192, 168, 1, 100}, 29999}, 2}}]
```

I can also check which groups I am participating in:

```elixir
  iex(9)> GroupManager.my_groups
  ["Group1"]
```

**How to leave a group**:

```elixir
  iex(10)> GroupManager.leave("Group1")
  :ok
  iex(11)> GroupManager.members("Group1")
  [{:net_id, {192, 168, 1, 97}, 29999}]
```

_Check how topology looks like now:_

```elixir
  [{:timed_item,
     {:item, {:net_id, {192, 168, 1, 97}, 29999}, :get, 0, 4294967295, 0},
     {:local_clock, {:net_id, {192, 168, 1, 97}, 29999}, 0}},
   {:timed_item,
     {:item, {:net_id, {192, 168, 1, 100}, 29999}, :rmv, 0, 4294967295, 0},
     {:local_clock, {:net_id, {192, 168, 1, 100}, 29999}, 3}},
   {:timed_item,
     {:item, {:net_id, {192, 168, 1, 100}, 29999}, :rmv, 15, 255, 11223},
     {:local_clock, {:net_id, {192, 168, 1, 100}, 29999}, 3}}]
```

Notice that all my `:add` and `:get` items are replaced with `:rmv` items, plus the associated clock number has increased. More explanation below.

### Communication between nodes

The group management messages have the basic properties of being idempotent so nodes can resend them any number of times and associative and communtative, so any order of applying messages lead to the same results. The majority of the inspiration comes from the CRDT datatypes and conference talks about idempotent messages. I had extensive ramblings about these in previous posts [like this one](/Scalesmall-W4-Message-Contents-Finalized/).

So once I designed the message contents I could focus on the message distribution which works like this at the high level:

1. every time I send a message to others I send it over UDP multicast first
2. the UDP multicast message has additional information about whom I have already received UDP multicast messages from (see `Gossip` type)
3. other peers do the same, so I will know who receives my UDP multicast messages
4. I send the other nodes through TCP via a logarithmic broadcast algorithm
5. when broadcasting I remove those from the recipient list who I think has received my message at step #1, except one random node that I will still contact directly
6. those who receive my message on TCP will send an UDP multicats in response

#### Logarithmic TCP broadcast

I started thinking about logarithmic TCP broadcast in [this](/Scalesmall-Experiment-Begins/) and [this](/Scalesmall-W5-UDP-Multicast-Mixed-With-TCP/) previous posts.

The ideas is to share the burden of transmitting data between nodes. Every time I broadcast to others I do this:

1. I contact one node on TCP and pass the message to be sent and half of the destinations I need to send to. The node who receives this message and destination list must start the same gossip procedure.
2. In the next turn I pick one node from the remaining destination set and repeat at step #1.

I keep repeating until the destination set is empty.

![Logarithmic broadcast](/images/log_broadcast.png)

The goal is to reduce the number of sends N1 does at the expense of a slightly larger messages. The `Gossip` message holds the extra data plus the original message payload.

#### Adding UDP multicast

The logarithmic broadcast has one issue though. When more nodes are involved in the message distribution, the more traffic is on the network. I added UDP multicast as an optimization to reduce the messages on the local network and also improve performance since the local network nodes will receive the information sooner.

When the nodes are spread accross multiple subnets, the UDP multicast optimization will only remove the local network nodes, so the broadcast tree will follow the network topology.

### GroupManager messages and data types

**Node identification**

Scalesmall nodes are identified by an IPv4 address and a port. This two items are represented by the [GroupManager.Chatter.NerID](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/chatter/net_id.ex) data type. The port is where the [GroupManager.Chatter.IncomingHandler](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/chatter/incoming_handler.ex) is waiting for new TCP packets.

```elixir
  defmodule GroupManager.Chatter.NetID do

    require Record

    Record.defrecord :net_id,
                     ip: nil,
                     port: 0

    @type t :: record( :net_id,
                       ip: tuple,
                       port: integer )

    # ... snip ...
  end
```
The IPv4 address follows the Erlang convention, it is a tuple of four integers.

**Broadcast identification**

Each UDP multicast is identified by the Node's `NetID` and a sequence number ([GroupManager.Chatter.BroadcastID](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/chatter/broadcast_id.ex)). The sequence number is not currently used, but later I plan to introduce expiry of the multicast topology, so if one node no longer able to receive multicast to be removed from the UDP multicast list.

```elixir
  defmodule GroupManager.Chatter.BroadcastID do

    require Record
    # ... snip ...

    Record.defrecord :broadcast_id,
                     origin: nil,
                     seqno: 0

    @type t :: record( :broadcast_id,
                       origin: NetID.t,
                       seqno: integer )
    # .. snip ..
  end
```

**Gossip**

The [GroupManager.Chatter.Gossip](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/chatter/gossip.ex) data type holds the extra metadata needed for the logarithmic broadcast and the UDP multicast optimization:

```elixir
  defmodule GroupManager.Chatter.Gossip do

    require Record
    # ... snip ...

    Record.defrecord :gossip,
                     current_id: nil,
                     seen_ids: [],
                     distribution_list: [],
                     payload: nil

    @type t :: record( :gossip,
                       current_id: BroadcastID.t,
                       seen_ids: list(BroadcastID.t),
                       distribution_list: list(NetID.t),
                       payload: term )
    # ... snip ...
  end
```

- `current_id` identifies the current broadcast/multicast
- `seen_ids` tell other whom this node has seen (for later optimization)
- `distribution_list` whom we are broadcasting to
- `payload` is any term

**Topology**

The group topology, that is which node serves which key range is represented by the [GroupManager.Data.Message](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/data/message.ex).

This type represents the shared knowledge about the group topology.

```elixir
  defmodule GroupManager.Data.Message do

    require Record
    # ..snip..
  
    Record.defrecord :message,
                     time: nil,
                     items: nil,
                     group_name: nil

    @type t :: record( :message,
                       time: WorldClock.t,
                       items: TimedSet.t,
                       group_name: binary )

    # ..snip..
  end
```

- `time` is a vector clock
- `items` is a timed set of items that each represent one particular participation information
- `group_name` 

### Implementation details

There are two protected ETS tables wrapped in services to hold the network and group topology information:

- [GroupManager.Chatter.PeerDB](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/chatter/peer_db.ex)
- [GroupManager.TopologyDB](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/topology_db.ex)

The network communication is handled by these services:

- [GroupManager.Chatter.IncomingHandler](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/chatter/incoming_handler.ex) receives TCP message
- [GroupManager.Chatter.OutgoingHandler](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/chatter/outgoing_handler.ex) sends TCP messages
- [GroupManager.Chatter.MulticastHandler](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/chatter/multicast_handler.ex) sends and receives UDP multicast messages

These services are part of supervision tree.

![GroupManager tree](/images/groupmantree.png)

### Areas to be improved

1. The current implementation uses `:erlang.term_to_binary` to translate the messages to a bunch of bytes and it compresses the message by Snappy. ([GroupManager.Chatter.Serializer](https://github.com/dbeck/scalesmall/blob/w11/apps/group_manager/lib/group_manager/chatter/serializer.ex))
2. I want to design a better serialization form that results both smaller messages and also being portable between languages. My goal is to be able to add non Elixir/Erlang nodes as well to the group topology.
3. The network and group topology information currently never shrinks, I only add new items, which will be a problem. I want to add some sort of expiry of the items.
4. When a node is only interested in a subrange it still receives the full topology which needs to be optimized.
5. Make the communication secure.

I realize this post became too long, so I want to dedicate one post to explain why and how are the messages idempotent, associative and commutative. Plus another post that dives more into this combination of TCP broadcast and UDP multicast.

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
