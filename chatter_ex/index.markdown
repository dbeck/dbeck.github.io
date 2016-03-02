---
published: true
layout: default
category: Elixir
tags:
  - elixir
  - scalesmall
  - chatter
desc: Chatter main page under construction
description: Chatter main page under construction
keywords: "Elixir, Distributed, Erlang, Scalable, Multicast, Broadcast"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF6936.JPG
woopra: chatter_exmain
scalesmall_subscribe: false
---

# Under construction

## Chatter library for Elixir

`Chatter` helps you in broadcasting information to a set of nodes. The messages are compressed and encrypted. The transfers utilize UDP multicast on the local network. For non local transfers `Chatter` builds a broadcast tree and try to involve more and more nodes in the message distribution.

### Message handler

`Chatter` assumes no knowledge about the messages except for few sanity checks. So we need to tell how to convert the objects to binary and back. Furthermore we need to provide a `dispatch` callback that will be called when a new message arrives. This information is passed through the `Chatter.MessageHandler` object. This must be registered through the `Chatter.SerializerDB`.

Once the `MessageHandler` is registered, it is ready to be used.

### Message delivery

Since `Chatter` uses UDP multicast, it is not guaranteed that all messages arrive. Messages may also be duplicated, since `Chatter` chooses a random node from the recipient list which will be contacted through TCP even if `Chatter` thinks the node would otherwise be available through UDP multicast.

### Node identification

`Chatter` uses an `(IPV4,Port)` pair to identify nodes. This information is represented by the `Chatter.NetID` tuple.

### Usage

```elixir
iex(1)> extract_netids_fn = fn(t) -> [] end
iex(2)> encode_with_fn = fn(t,map) -> :erlang.term_to_binary(t) end
iex(3)> decode_with_fn = fn(b,map) -> {:erlang.binary_to_term(b), <<>>} end
iex(4)> dispatch_fn = fn(t) -> {IO.inspect(["arrived", t]), t} end
iex(5)> handler = Chatter.MessageHandler.new(
    {:hello, "world"},
    extract_netids_fn,
    encode_with_fn,
    decode_with_fn,
    dispatch_fn)
iex(6)> db_pid = Chatter.SerializerDB.locate!
iex(7)> Chatter.SerializerDB.add(db_pid, handler)
iex(8)> Chatter.broadcast([{:net_id, {192, 168, 1, 100}, 29999}], {:hello, "world"})
```

### More information

[see package at github](https://github.com/dbeck/chatter_ex)
[the original blog post about Chatter](/Chatter-extracted-from-ScaleSmall/)

# Under construction
