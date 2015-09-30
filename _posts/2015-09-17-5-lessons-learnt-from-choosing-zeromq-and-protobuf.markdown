---
published: true
layout: post
category: ZeroMQ
tags: 
  - 0mq
  - protobuf
  - protocol-buffers
desc: 5 lessons learnt from choosing ZeroMQ + Protocol Buffers
keywords: "Distributed, ZeroMQ, Protocol Buffers, Programming, Performance"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF6937.JPG
woopra: zeromqprotobuf
---

We implemented a new distributed system from scratch. One of the goals was to make this extendible by adding new components easily in different programming languages. I was looking for a solution to pass serialized data between them without worrying too much about performance and cross language compatibility. This practically ruled out a few popular options at square one, like HTTP, Json, XML, Web Services. Fortunately there were quite some others:

* [ZeroMQ](http://zeromq.org) + [Protobuf](https://developers.google.com/protocol-buffers/?hl=en) 
* [Thrift](https://thrift.apache.org)
* [Avro](https://avro.apache.org/docs/current/)

Originally these options didn't look like very different. All have efficient serialization. Handle data transport between components and cover many programming languages.

I liked ZeroMQ + Protobuf option better than the others because it sounded like well optimized transport with Publish-Subscribe built in.

This topic is about a few of our experiences that we earnt the hard way.

### 1. ZeroMQ Request Reply

If I were creating the ZeroMQ docs I would start with "Don't use REQ-REP because there is very little chance that it does what you need". What I found instead is that it starts describing REQ-REP as a showcase of how easy it is to use ZeroMQ.

The issue with REQ-REP is that it allows one request to be served in parallel and due to the fact that it requires to send a reply for every request it is very fragile. 

Example: I have a third party service that I want to wrap in a ZeroMQ interface. I am receiving ZeroMQ requests that I translate into a native request to this third party service. If this external service becomes slow or stops responding than it becomes very inconvenient to handle this on the ZeroMQ side.

Advice: use REQ-ROUTER sockets all the time because REP sockets are pretty useless for any real world application.

### 2. ZeroMQ Portability

When I read the docs I was happy to see that ZeroMQ has many language bindings so this is pretty portable. In other places I read that it is secure thanks to the developments introduced in 4.x and upwards. What people forgot to mention is that these two don't happen at the same time.

Even if there is a security model in 4.x, it is not available in many language bindings that I was interested in. These are niche languages that very few people use like [Java](http://zeromq.org/bindings:java) that has no support for 4.x. Other less common choices like Erlang, Elixir are also unavailable if you want security.

### 3. Protocol Buffers Performance

I trusted protobuf quite a lot at the beginning of the project even to the point when we ran into a performance issue I was rather looking at very unlikely places than protobuf. When I analyzed the issue further it slowly became clear that protobuf has a few weaknesses. Memory allocation is the biggest. 

In our case we passed values in arrays. It turned out that passing string arrays is hopelessly slow and passing numeric types in arrays is about twice as slow as it could be. The reason is memory allocation. Protobuf allocates a string object for each string item it receives in the array. A typical message in our system has 25.000 strings or numerics in the array we pass. 

I chose to write a deserializer for this one message type that reuses the tag bytes as zero terminator between the elements in the string array. For the numeric types I preallocated a large enough buffer in one step to place my items into that. Ther result is 20x faster for strings and twice as fast for numeric types.

Advice: look at [flatbuffers](https://google.github.io/flatbuffers/md__benchmarks.html)

### 4. Protocol Buffers Size Constraints

The default message size limit is 64MB for protocol buffers. This can be changed. In our case, for every single programming language that we want to support. Not very convenient.

### 5. Protocol Buffers Enums

One often advertised feature of protobuf is that it is easy to be extended by new messages. We created a wrapper message with an enum to tell what kind of optional message follows. This allowed us to occasionally add new message types into the outer wrapper. We realized afterwards that different language bindings have different tolerance for this approach. 

Hint: C++ and Javascript differs significantly.

