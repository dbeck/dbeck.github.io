---
published: true
layout: default
category: "Chatter for Elixir"
tags:
  - elixir
  - scalesmall
  - chatter
  - gossip
desc: Chatter for Elixir (0.0.12)
description: Chatter for Elixir (0.0.12)
keywords: "Elixir, Distributed, Erlang, Scalable, Multicast, Broadcast"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/mixed_broadcast1.png
woopra: chatterex_main_v0_0_12
scalesmall_subscribe: false
---

# Chatter for Elixir (Chatter 0.0.12)

- [Intro blog post about Chatter](/Chatter-extracted-from-ScaleSmall/)
- [Quickstart Guide](quickstart.html)
- [Communication internals](communication.html)

## Purpose

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

