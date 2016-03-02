---
published: true
layout: default
category: "Chatter for Elixir"
tags:
  - elixir
  - scalesmall
  - chatter
  - gossip
desc: Chatter Quickstart Guide (0.0.11)
description: Chatter Quickstart Guide (0.0.11)
keywords: "Elixir, Distributed, Erlang, Scalable, Multicast, Broadcast, Gossip"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/log_broadcast.png
woopra: chatterex_quickstart_v0_0_11
scalesmall_subscribe: false
---

# Quickstart Guide (Chatter 0.0.11)

- add dependency
- start the application
- set configuration values, especially the encryption key
- register handler
- broadcast to others

## Add dependency

```elixir
  defp deps do
    [
      {:xxhash, git: "https://github.com/pierresforge/erlang-xxhash"},
      {:chatter, "~> 0.0.11"}
    ]
  end
```

## Start the application

```elixir
  def application do
    [
      applications: [:logger, :chatter],
      mod: {YourModule, []}
    ]
  end
```

## Configure

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

## Register message handler

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
iex(6)> db_pid = Chatter.SerializerDB.locate!
iex(7)> Chatter.SerializerDB.add(db_pid, handler)
```

## Broadcast to others

```elixir
iex(8)> destination = Chatter.NetID.new({192, 168, 1, 100}, 29999)
iex(9)> Chatter.broadcast([destination], {:hello, "world"})
```

# Other docs

- [Intro blog post about Chatter](/Chatter-extracted-from-ScaleSmall/)
- [Overview](index.html)
- [FAQ](faq.html)
- [Communication internals](communication.html)
