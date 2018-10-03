---
published: true
layout: post
category: "ActorRS"
tags:
  - Rust
  - actor
  - concurrency
desc: "Rust Actor Library: Follow up"
description: "Rust Actor Library: Follow up"
keywords: "Rust, Actor, Concurrency"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF0485.JPG
pageid: actors_follow
scalesmall_subscribe: false
---

I have received lots of feedbacks for my [previous post](/Rust-Actor-Library-First-assorted-thoughts/) which helped me deciding what to write about in this follow up. Thank you!

![first](/images/DSCF0485.JPG)

### The state of the library

This is a proof of concept at the moment. An experiment, that I play with in my spare-time. No one pays me for developing this. I am sharing it in the hope that some people will find it interesting and may be we can have interesting chats about it. I have a few use-cases in my mind, but they are cider-ware.

### History

I wanted to see how an actor library would look like in Rust. I had two motivations for building this in Rust:

1. Build on the strong type system.
2. See how fast it can get.

I originally started with `Any` messages for simplicity, but I realized that:

1. Using [Any](https://doc.rust-lang.org/beta/std/any/trait.Any.html)s with Rust stable is not convenient and I didn't want to use nightly Rust. (`acto-rs` is still on stable Rust BTW)
2. I had an uneasy feeling with `Any`s, because I felt that I am not leveraging Rust's type system.

So I decided to use typed [messages](https://github.com/dbeck/acto-rs/blob/0.5.2/src/lib.rs#L45). If the messages are typed then the channels to transport them will better be typed otherwise I end up doing down-up casting all the time.

So I nailed down typed channels between actors and I wanted these actors to be run by a pool of threads. The next step is to pass these actors to the pool which is easy by letting them implementing a trait. I call this trait a `Task`.

So that I have a task pool, I want to send messages to the tasks. There are two issues around them:

1. How to locate the one I am sending to?
2. How should the message sending interface look like?

The first one seem to be trivial. I just need to identify the tasks and look them up in a collection. But the collection will give me a `Task` object which has typed channels somewhere inside, which implies that at some point I will need do the up-down casting again. I decided against it.

The other issue is similar. If I want to send typed messages I would need typed interfaces.

For these reasons I decided to let the task pool (I call this [Scheduler](https://github.com/dbeck/acto-rs/blob/0.5.2/src/scheduler/mod.rs#L10)) only taking care of executing the tasks and the connection between the tasks to be set up before they are passed to the scheduler. This saves the up-down casting of messages.

So I departed from the Erlang/OTP actor model for type safety. As a side note, the missing type checking was the reason why I stopped using Elixir. I love lots of things in the Elixir language, but even for a moderate project I ended writing too many tests to make sure I am passing the right types.

I feel that Rust's strong type system compensates for not being able to send messages to any actor any time. I decided that the topology must be fixed before the actors are passed to the scheduler. The scheduler is dynamic in the sense that it can receive new tasks anytime. So if another topology is needed I can still create new tasks with that new topology and pass it to the scheduler.

### Message channels

The channels between the tasks are asynchronous. Actually in more than one sense. They are asynchronous because there need not be a receiver to send a message. The sender is not blocked by the receiver in any ways. If the message channel's size is not large enough, then the sender will overwrite old messages.

It can get the old message before being overwritten and may decide to pile it up, so the message loss can be prevented. However, I do think that it is a bad strategy. If the message queues have reasonable capacity to handle temporary peaks, and they still get filled up, that usually means that the receiver is slower, in which case the sender should better throw away messages. It is a choice whether the new one or the old one to be thrown away, depending on the application.

The nice part of the message channels is that they have preallocated buffers. The queues don't allocate memory afterwards. This makes memory size and latency predictable.

### Convenience features

I found that readers of my previous intro post got confused by the scheduling rules. This is my mistake because I started writing about those rules that are not actor-system-like. The natural choice would have been the  [OnMessage](https://github.com/dbeck/acto-rs/blob/0.5.2/src/lib.rs#L69) scheduling rule which tells the scheduler that the actor to be run when it received a message. This fits into the actor theory which talks about actor states that are changed in response to the messages received.

I also found that periodically executed tasks could make sense in many situations so I added a scheduling rule for that too. With a bit of imagination this can also fit into the actor model when we treat the timing events as special messages.

Finally I thought that the actors need to respond to outside events too. These can be network, OS, or any other events that happens outside the actor world. I quickly realized that it is not economical to write a new network event loop and also all the other possible event sources. I believe there are great crates for them already in Rust, so I wanted to integrate with them. I found the easiest is to provide some means for the external world to trigger execution of a task in the actor world. This is why I have the [OnExternalEvent](https://github.com/dbeck/acto-rs/blob/0.5.2/src/lib.rs#L71) scheduling rule. This tells the scheduler that the given task only need to be executed if triggered from the outside. Probably by a MIO event loop...

### Topology

As I explained above, the actors need to be connected to each other before they are passed to the scheduler. The scheduler needs to know about the channels and the connections to be able to run the right task when it received a message (if the scheduling rule is `OnMessage`).

I believe there are two benefits of using the [elem traits](https://github.com/dbeck/acto-rs/tree/0.5.2/src/elem):

1. It is convenient, because only one `process(..)` function needs to be implemented for them. See the [Filter trait](https://github.com/dbeck/acto-rs/blob/0.5.2/src/elem/filter.rs#L13) as an example.
2. They document the connection topology so if you have lots of actors they help organizing the project.

One of the feedbacks I received is that the so many different types and traits are so complicated that it is hardly an actor system. Look at Erlang/Go/Akka they don't need this much complexity. The good news is that you don't need to use all elem types, scheduling rules, etc... to start, but when you want typed channels, somehow they need to be described.

### Focus on predictable and fast speed

I was surprised when I measured an other (unnamed) actor system's speed. It took over a microsecond to send a few bytes to an actor from the sender's time. The total time to actually deliver the message was even higher. I wanted to see how much better we can get in Rust. I made a decision not publish any performance figures or comparisons, but I do encourage you to measure yourself.

### Topics for next posts

1. I want to show you how this library allows you to write an actor that encapsulates state which is then changed on message events
2. I want to show how to use a few element types. How to connect them and how to pass messages in between
3. How to handle errors in the message flow

If you have questions, feedbacks or recommendation for an area that needs better explanation, please don't hesitate to contact me. Feedbacks help a lot and are highly appreciated!

### Update

I have written a [new post](/Example-Source-and-Sink/) with another, more actor-like example.
