---
published: true
layout: post
category: Elixir
tags: 
  - elixir
  - distributed
  - scalesmall
  - UDP-Multicast
desc: ScaleSmall Experiment Week Five / UDP Multicast Mixed With TCP
keywords: "Elixir, Distributed, Erlang, Macro, High-performance, Scalable, UDP, Multicast"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF4245.JPG
woopra: scalesmallw5
scalesmall_subscribe: true
---

This post goes in reverse order, rather than starting with something abstract and progress towrads the results, I start with something that may be useful for you independent of the scalesmall experiment. Then I will slowly move to the big picture, the applicability of the useful bits in scalesmall and the rationale.

**This blog post is about**:

- Embed ranch
- UDP multicast in Elixir
- UDP multicast in general
- Logarithmic TCP broadcast
- Combining UDP multicast and the logarithmic broadcast
- How do all these fit into scalesmall

![friends](/images/DSCF4245.JPG)

### Embed ranch

[Ranch docs](http://ninenines.eu/docs/en/ranch/1.1/guide/embedded/)

### UDP multicast in Elixir

To do UDP multicast in Elixir I have multiple options:

- use the [meh/elixir-socket](https://github.com/meh/elixir-socket) library
- use the [Erlang gen_udp](http://www.erlang.org/doc/man/gen_udp.html) 

I tried `elixir-socket` first and couldn't get it working in an hour. There is no doc about the UDP multicast, so I started to dig into the code and realized that it is a convenience layer on top of `gen_udp`. What I found very disturbing is that the original Erlang keywords are mapped to similar looking, but different keywords. While `gen_udp` is documented, the magic in `elixir-socket` is not, so I decided to rather go with the gen_udp.

#### Multicast receiver

Here is my sample UDP multicast receiver:

``` Elixir
defmodule MulticastReceiver do
  
  use GenServer
    
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end
  
  def init (:ok) do
    udp_options = [
      :binary, 
      active:          10,
      add_membership:  { {224,1,1,1}, {0,0,0,0} },
      multicast_if:    {0,0,0,0},
      multicast_loop:  false,
      multicast_ttl:   4,
      reuseaddr:       true
    ]
    
    {:ok, _socket} = :gen_udp.open(49999, udp_options)
  end
  
  def handle_info({:udp, socket, ip, port, data}, state)
  do
    # when we popped one message we allow one more to be buffered
    :inet.setopts(socket, [active: 1])
    IO.inspect [ip, port, data]
    {:noreply, state}
  end  
end
```

**Try it out**

I used `netcat` as:

```
$ nc -u 224.1.1.1 49999
hello 
world
^C
```

The response was:

```
$ iex 
Erlang/OTP 18 [erts-7.1] [source] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.1.1) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> receiver = MulticastReceiver.start_link
{:ok, #PID<0.59.0>}
[{192, 168, 1, 100}, 60497, "hello\n"]
[{192, 168, 1, 100}, 60497, "world\n"]
iex(2)>
```

The interesting parts in the `MulticastReceiver` example are:

- multicast address / interface / membership
- `active` role
- TTL

I only pick interesting parts of this topic and include references for the boring parts.

#### Multicast address and membership

UDP multicast is an interesting animal, because declaring that I want to receive multicast messages impacts the link layer. This is in contrast with what we normally do with other UDP and TCP sockets when we operate above that and don't mess with the MAC addresses. Plus I think the way it got implemented in the BSD socket API is pretty much of a hack.

The multicast membership has a corresponding link layer address which has a special mapping. Let's see how it looks:

```
$ netstat -ng
Link-layer Multicast Group Memberships
Group               	Link-layer Address	Netif
1:0:5e:1:1:1        	<none>          	en0
1:0:5e:0:0:fb       	<none>          	en0
1:0:5e:0:0:1        	<none>          	en0
...snip...

IPv4 Multicast Group Memberships
Group               	Link-layer Address	Netif
224.0.0.251         	<none>          	lo0
224.0.0.1           	<none>          	lo0
224.1.1.1           	1:0:5e:1:1:1    	en0
224.0.0.251         	1:0:5e:0:0:fb   	en0
224.0.0.1           	1:0:5e:0:0:1    	en0

IPv6 Multicast Group Memberships
...snip...
```

The `add_membership ... {0,0,0,0}` option above tells the OS that, on every interface, we want the OS to send us the multicast packets targeted to the `224.1.1.1` multicast address. This translates to the special `1:0:5e:1:1:1` MAC address as seen above.

In C this would be achieved by the [setsockopt(socket, IPPROTO_ IP, IP_ ADD_MEMBERSHIP,...)](http://man7.org/linux/man-pages/man7/ip.7.html) call which is what Erlang calls at the end of the day.

#### The `active` role

The Erlang's active role is a real gem. It allows us to choose between receiving the UDP messages as normal GenServer messages or we can explicitly call [recv/2 or /3](http://www.erlang.org/doc/man/gen_udp.html#recv-2) to gather the messages. I think the former method fits the OTP way a lot better. This nicer way is the so called `active mode`.

If I am in passive mode, when using `active: false` then I would need to choose between either wait indefinitely with `recv/2` or do an internal loop with `recv/3` and pick a timeout for that. Both are bad because I need to take care of the incoming other messages/GenServer commands while I am waiting for the UDP messages in `recv/[2,3]`.

Because of these complications I feel more natural to use active mode as opposed to `active: false`.

For the active mode I have multiple options:

- **active: true** : converts all incoming messages to GenServer messages and passes them right away to `handle_info`. This is pretty dangerous as the network can overflow the Erlang message queue
- **active: :once** : passes one single incoming message to `handle_info` and then it switches back to passive. To continue as an active socket we need to shoot `:inet.setopts(socket, [active: :once])` again. This allows nice control over the socket.
- **active: NUMBER** : passes NUMBER messages to `handle_info` and decrement NUMBER until it reaches zero, when it becomes passive. We can call `:inet.setopts(socket, [active: INCREMENT])` where the INCREMENT number will be added to the actual NUMBER.

I like this latter option most, because it allows a bounded number of messages to be enqueued in the Erlang message queue.

If you look at the example code above you can see that I used `active: 10` to start with a 10 element buffer and I called `:inet.setopts(socket, [active: 1])` in handle_info(...) to compensate for the message I just processed.

#### Erlang IP addresses in Elixir

The `gen_udp` interface is pretty rough when bad arguments are passed to it. It barks a `bad_arg` and done. This is what I got most of the time when I used `meh/elixir-socket`. The rules are simple though:

- Erlang wants tuples as IP addresses, like {224,1,1,1}
- When I want Erlang to convert to these tuples it usually wants character lists as input

``` Elixir
  ex(1)> "127.0.0.1" |> String.to_char_list |> :inet.parse_address
  {:ok, {127, 0, 0, 1}}
```

These I guess is obvious if you have spent some time in the Erlang world. But I have not.

### UDP multicast in general

The best part of UDP multicast is that it sits between unicast and broadcast and allows selective reception of multicasted messages. At the same time I can shoot a single message to multiple hosts. Multicast also has limitations, like it may or may not work on WANs, because not all routers allow multicast. The multicast address you choose also has impact on its scope. It can be local, site only, global, etc... The TTL field also limits how far the packet reaches.

There are lots of good literature about UDP multicast. I recommend [Unix Network Programming, Volume 1: The Sockets Networking API](http://www.amazon.com/Unix-Network-Programming-Volume-Networking/dp/0131411551) by W. Richard Stevens.

### Logarithmic TCP broadcast

TCP by its nature is unicast. What we can do is to open as many TCP sockets as needed and send the broadcasted message on all these unicast channels in a loop. An improvement over this scenario is to delegate this broadcast job to multiple hosts, so in a lucky case the broadcast could take shorter time.

The idea I have for the delegation is to send a `NodeList` together with the `Message` to the next hop, so the next hop is requested to pass the `Message` to the nodes in the `NodeList`.

```
 Chatter@HOST(node_list, message)
```

Let's suppose I have 8 nodes [N1, N2, N3, N4, N5, N6, N7, N8] and want to distribute M message to these. Then I would call Chatter on N1 like this:

```
 Round 1:
 --------
 Client -> Chatter@N1([N1, N2, N3, N4, N5, N6, N7, N8], M)
 # M gets delivered locally at N1
 # --> M delivered at N1

 Round 2:
 -------- 
 # N1 halves the remaining list => [N2, N3, N4, N5]
 Chatter@N1 -> Chatter@N2([N2, N3, N4, N5], M)
 # M gets delivered locally at N2
 # --> M delivered at N1, N2
 
 Round 3:
 --------
 # N1 halves the remaining list -> [N6, N7]
 # N2 halves its remaining list -> [N3, N4]
 Chatter@N1 -> Chatter@N6([N6, N7], M)
 # M gets delivered locally at N6
 Chatter@N2 -> Chatter@N3([N3, N4], M)
 # M gets delivered locally at N3
 # --> M delivered at N1, N2, N3, N6
 
 Round 4:
 --------
 Chatter@N1 -> Chatter@N5([N8], M)
 # M gets delivered locally at N8
 Chatter@N2 -> Chatter@N5([N5], M)
 # M gets delivered locally at N5
 Chatter@N3 -> Chatter@N4([N4], M)
 # M gets delivered locally at N4
 Chatter@N6 -> Chatter@N7([N7], M)
 # M gets delivered locally at N7
 # --> M delivered at N1, N2, N3, N4, N5, N6, N7, N8
```

### Combining UDP multicast and the logarithmic broadcast

I think the logarithmic broadcast on a LAN could cause issues as the required bandwith grows exponentially in each round. The good news is that we have just discovered UDP broadcast, so we don't need to go havoc on the LAN, but a single multicast would suffice for the local nodes.

I would like my broadcast to support multi data center setups and NATed subnets too. The best solution would be to use the logarithmic TCP broadcast across subnet boundaries and within the subnet I would stick to UDP multicast. I just need to figure out which nodes receive the multicast messages.

In each multicast round I would attach source information to the message which would have a Node ID plus a multicast sequence ID. The receivers of the multicast messages would record these info and attach them to the outgoing messages, both on TCP and UDP multicast. The network would slowly learn which hosts reach each other on multicast and where we need TCP.

Since UDP messages are not reliable, I would randomly choose to force TCP conversation even if UDP multicast is available.

### How do all these fit into scalesmall

The scalesmall experiment is about building up a distributed messaging platform from zero while maximizing the fun factor. This platform should be focusing on being optimal for small messages of less than 100 bytes on average. I have the ambitious goal of doing at least 1 million small messages per node reliably.

The first problem I want solve is how to form a group from a bunch of nodes. I came up with a message protocol in the [previous episode](/Scalesmall-W4-Message-Contents-Finalized/), that I have [implemented too](https://github.com/dbeck/scalesmall/tree/w4/apps/group_manager/lib/group_manager/data).

I am currently working on the theory and implementation of passing the actual messages between nodes, hence this post is about the broadcast/multicast topics. So this is pretty much the beginning of an experimental gossip protocol.

