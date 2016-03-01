---
published: true
layout: post
category: "Chatter for Elixir"
tags:
  - elixir
  - scalesmall
  - chatter
desc: Chatter extracted from ScaleSmall
description: Chatter extracted from ScaleSmall
keywords: "Elixir, Distributed, Erlang, Scalable, Broadcast, Multicast, UDP"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF6941.JPG
woopra: chatter_extracted
scalesmall_subscribe: false
---

Scalesmall progresses towards the final goal of being a scalable message queue optimized for small messages.

When the `GroupManager` completed I started designing the next step which is the actual functionality to receive, store and forward messages.

I quickly realized that the existing `Chatter` component should be reused at a number of places, only that I need to:

- cut a few dependencies to the `GroupManager`
- start a [github repo for Chatter](https://github.com/dbeck/chatter_ex)
- publish it to [hex.pm too](https://hex.pm/packages/chatter)
- improve documentation

![nice](/images/DSCF6941.JPG)

### Chatter use-case

1. `Chatter` can send messages to a set of nodes.
2. While doing so it compresses and encrypts the data.
3. It minimizes the network traffic by utilizing UDP multicast for the recipients on the same network.
4. `Chatter` learns who is on the same network, no extra configuration is needed.
5. Chatter nodes sharing the same key form a group similar to the Erlang nodes, except that `Chatter` doesn't monitor node status.
6. `Chatter` discovers other nodes by receiving UDP multicast messages from other nodes (only if they share the same `key`)
7. It uses a TCP based logarithmic broadcast to other nodes on non-local networks.
8. `Chatter` doesn't interfere with existing Erlang and Elixir libraries that builds on the BEAM VM node/distributed facilities.
9. Chatter aims to be portable across programming languages, by using a very simple message structure and no Erlang/Elixir specifics.
10. `Chatter` can call different message serialization and dispatch callbacks based on the message type.

### Node identification

Nodes are identified by an IPv4 address and port pair. The IPv4 address follows the Erlang way, being a four element tuple.

```elixir
  defmodule Chatter.NetID do
    require Record
    Record.defrecord :net_id, ip: nil, port: 0
    @type t :: record( :net_id, ip: tuple, port: integer )
    # ... snip ...
  end
```

Chatter also uses [BroadcastID](https://github.com/dbeck/chatter_ex/blob/master/lib/broadcast_id.ex) which is a [NetID](https://github.com/dbeck/chatter_ex/blob/master/lib/net_id.ex) and a sequence number.

### Message structure

The `Chatter` message structure is designed to be secure and small. Since the NetIDs are central to Chatter, they appear at many places in the message:

- when identifying the sender
- when passing the message distribution list to other nodes
- when telling other nodes, who we received multicast messages from
- (and the GroupManager is also using them at its LocalClock and WorldClock)

Because of this widespread and often redundant usage, I decided to factor out the NetIDs into a `NetID table`. This adds extra complexity at the message encoding and decoding but gives a huge shrink in the message size, both because of the removed redundancy and also because of compression is more efficient.

![structure](/images/chatter_message_structure.png)

### Message encoding

The high level flow of message encoding is:

- gather the NetIDs from the Gossip and the Payload (by calling the user supplied `extract_netids` callback)
- create a map of `NetID` -> `Table position`
- encode the Gossip with the help of the NetID map
- inserts a user supplied `Payload Type Tag` into the message
- call a user callback `encode_with` with the Payload and the NetID map to convert the payload to binary

To be able to serialize the user content, Chatter needs a few callbacks to be registered. Please see the details below, in the `MessageHandler` section.

### Message decoding

- chatter extracts the NetID table from the incoming message
- converts the NetIDs to a map of `Table position` -> `NetID`
- decodes the `Payload Type Tag` from the message and finds the registered callback for the given message type
- calls the registered `decode_with` callback with the Payload binary and the `Table Postion` -> `NetID` map
- calls the registered `dispatch` function with the result of the decode step

### MessageHandler

To be able to handle messages the user needs to pass five information to the Chatter library:

1. How to match the incoming message types with the user supplied deserialization code?
2. (Optionally) How to extract NetIDs from the user payload if there is any? (`extract_netids`)
3. How to convert the user object to binary? (`encode_with`)
4. How to convert the binary message to an user object? (`decode_with`)
5. What to do with the incoming messages? (`dispatch`)

Here is a very simple and inefficient illustration:

```elixir
iex(1)> extract_netids_fn = fn(t) -> [] end
iex(2)> encode_with_fn = fn(t,_id_map) -> :erlang.term_to_binary(t) end
iex(3)> decode_with_fn = fn(b,_id_map) -> {:erlang.binary_to_term(b), <<>>} end
iex(4)> dispatch_fn = fn(t) -> IO.inspect(["arrived", t])
  {:ok, t}
end
iex(5)> handler = Chatter.MessageHandler.new(
    {:hello, "world"},
    extract_netids_fn,
    encode_with_fn,
    decode_with_fn,
    dispatch_fn)
```

The user in this example doesn't want to use the `NetID table`, so the `extract_netids` function returns an empty list. The `encode_with` and `decode_with` functions are using the Erlang serialization functions. The encoder and decoder just ignore the id_map parameter, beause they don't need it. The `dispatch` function prints the incoming record.

The `MessageHandler` also needs to be registered so `Chatter` will know about it:

```elixir
iex(6)> db_pid = Chatter.SerializerDB.locate!
iex(7)> Chatter.SerializerDB.add(db_pid, handler)
```

The first parameter of the message handler takes a tuple and assumes the first element to be an atom. This will be converted to string and a 32 bit checksum of this string will identify the message type both in the SerializerDB and the `Payload Type Tag` field of the message.

`Chatter` assumes that the user passes tuples as message data and the first element of the tuple is an atom that identifies the message type.

### Sending messages

Once we registered our message handler we are ready to send messages to others:

```elixir
iex(1)> destination = Chatter.NetID.new({192, 168, 1, 100}, 29999)
iex(2)> Chatter.broadcast([destination], {:hello, "world"})
```

When `Chatter` receives a valid message it records the peers `Seen IDs` list into its `PeerDB` database. It slowly learns about the local network and the list of collected IDs can be gathered like this:

```elixir
iex(1)> Chatter.peers
[{:net_id, {192, 168, 1, 100}, 29999}]
```

One may do a broadcast to all known peers this way:

```elixir
iex(1)> Chatter.peers |> Chatter.broadcast({:hello, "world"})
```

### Chatter configuration

Chatter needs a few configuration items to operate. Some of them may be omitted and the defaults work fine. Please make sure you set your own `:key` to make the communication secure.

The example below allows overriding the configuration values by environment variables. This is only for convenience, `Chatter` doesn't require these environment variables to be set.

```elixir
use Mix.Config

config :chatter,
  my_addr: System.get_env("CHATTER_ADDRESS"),
  my_port: System.get_env("CHATTER_PORT") || "29999",
  multicast_addr: System.get_env("CHATTER_MULTICAST_ADDRESS") || "224.1.1.1",
  multicast_port: System.get_env("CHATTER_MULTICAST_PORT") || "29999",
  multicast_ttl: System.get_env("CHATTER_MULTICAST_TTL") || "4",
  key: System.get_env("CHATTER_KEY") || "01234567890123456789012345678912"
```

#### :my\_addr and :my\_port

`:my_addr` is where Chatter binds its TCP listener for receiving incoming TCP traffic. If not given `Chatter` tries to determine the local IPv4 address:

```elixir
    iex(1)> Chatter.get_local_ip
    {192, 168, 1, 100}
```

If not specified TCP port `29999` is used.

The resulting local address can be queried like this:

```elixir
  iex(1)> Chatter.local_netid
  {:net_id, {192, 168, 1, 100}, 29998}
```

#### :multicast\_address, :multicast\_port and :multicast\_ttl

These configuration values determine the UDP multicast parameters. The defaults are:

- multicast_address: 224.1.1.1
- multicast_port: 29999
- multicast_ttl: 4

#### :key

`Chatter` encrypts all messages using 256 bit AES encryption. Nodes that don't share the same key, won't be able to understand each other.

The encryption key needs to be 32 characters long. The longer keys will be chopped, the shorter keys will be concatenated with `01234567890123456789012345678901` and then chopped to 32 characters.

#### Start

`Chatter` is now on [hex.pm](https://hex.pm/packages/chatter) so you can do:

```elixir
  defp deps do
    [
      {:xxhash, git: "https://github.com/pierresforge/erlang-xxhash"},
      {:chatter, "~> 0.0.11"}
    ]
  end
```

Start the application too:

```elixir
  def application do
    [
      applications: [:logger, :chatter],
      mod: {YourModule, []}
    ]
  end
```

### Communication internals

Chatter uses a TCP based unicast for spreading the messages. However it has a few twists on that. The first is a logarithmic message distribution that I described in a few other posts too: I started thinking about logarithmic TCP broadcast in [this](/Scalesmall-Experiment-Begins/) and [this](/Scalesmall-W5-UDP-Multicast-Mixed-With-TCP/) posts.

#### Logarithmic TCP broadcast recap

The ideas is to share the burden of transmitting data between nodes. Every time I broadcast to others I do this:

1. I contact one node on TCP and pass the message to be sent and half of the destinations I need to send to. The node who receives this message and destination list must start the same gossip procedure.
2. In the next turn I pick one node from the remaining destination set and repeat at step #1.

I keep repeating until the destination set is empty.

![Logarithmic broadcast](/images/log_broadcast.png)

The goal is to reduce the number of sends N1 does at the expense of a slightly larger messages. The `Gossip` message holds the extra data plus the original message payload.

#### UDP multicast optimization

`Chatter` saves the `Seen ID list` for every message it receives. Based on that it knows if other peers claim that they have received UDP multicast messages from the given node. If this indicates that the destination does receive multicast from us, then we are free to use it instead of TCP. We both would benefit since the peer will have the information sooner and the delivery is less work for us.

`Chatter` replaces the `Seen ID list` and the `BroadcastID` on every packet it forwards to the information corresponds to the given node.

To illustrate how it works, let's compare the two images below. The first shows the TCP only logarithmic broadcast. It involves more and more nodes in the communication at every round.

![TCP Only](/images/tcp_broadcast.png)

Let's suppose the nodes reside on two subnets, A and B. The multicast messages don't travel between these given subnets, thus some nodes can be removed from the TCP distribution list, but not all.

![mixed](/images/mixed_broadcast1.png)

Subnet A receive the message right away through multicast, and subnet B receives it at the second round. Subnet B receives it twice more because the second and third TCP targets will send multicast messages again while eliminating the TCP targets. If the initiator would be smarter, subnet B would receive less traffic. This optimization is yet to be developed.

The end result is that both subnets receive less traffic and the message spread faster by the multicast optimization.

#### Not all nodes are eliminated

The first step at every broadcast is that `Chatter` sends out the message on multicast unconditionally. Then it checks the destination lists and removes those nodes that should have received the message on multicast at the first step. The remaining nodes will be contacted by the logarithmic TCP broadcast.

It has a high chance that every node on the local network will be removed from the distribution list, sooner or later. Since UDP is not reliable this would mean that we base all communication on an unreliable channel for the local network, which is not desirable. For that reason, `Chatter` always keeps a random node of the original distribution list, no matter what the UDP `Seen IDs list` says, and this random node will be contacted on TCP too.

#### Messages duplicated, multiplicated

It is very likely that messages will be delivered multiple times to nodes, so the application need to handle that. `GroupManager` actually benefit from this because the `MessageHandler`'s `dispatch` callback works in a special way. It not just receives an object but can return a different object of the same type. This result object will be included in the next message transfer round and allows the application to merge in changes or additional information while the gossip progresses.
