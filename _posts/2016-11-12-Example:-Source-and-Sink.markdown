---
published: true
layout: post
category: "ActorRS"
tags:
  - Rust
  - actor
  - concurrency
desc: "Example: Source and Sink (Actors)"
description: "Example: Source and Sink (Actors)"
keywords: "Rust, Actor, Concurrency"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF0473.JPG
woopra: actors_ex1
scalesmall_subscribe: false
---

As promised in my [first post](/Rust-Actor-Library-First-assorted-thoughts/) I show an example of using [acto-rs](https://github.com/dbeck/acto-rs/tree/0.5.2). My goal is to demonstrate how to write actors that have an encapsulated state which the actor can change when new message arrives. I also want to show how an actor sends messages.

![first](/images/DSCF0473.JPG)

### Where is the actor state?

It is in a struct that you create. It holds state in the member variables of your choice. An example struct would be this:

```rust
struct SendGreatingsActor {
  last_sent: usize,
}
```

([Code here.](https://github.com/dbeck/acto-rs-playground/blob/0.0.1/src/great_int.rs#L4))

This is another silly example for demonstration purposes. The `SendGreatingsActor` sends integers as a greating to a receiver. The `last_sent` value is its state.

### How does the actor send messages?

```rust
impl source::Source for SendGreatingsActor {

  type OutputValue = usize;
  type OutputError = String;

  fn process(&mut self,
             output: &mut Sender<Message<Self::OutputValue, Self::OutputError>>,
             _stop: &mut bool)
  {
    output.put(|value| *value = Some(Message::Value(self.last_sent)) );
    self.last_sent += 1;
  }
}
```

([Code here.](https://github.com/dbeck/acto-rs-playground/blob/0.0.1/src/great_int.rs#L8))

The `SendGreatingsActor` implements the [source element trait](https://github.com/dbeck/acto-rs/blob/0.5.2/src/elem/source.rs#L5) which has a single output channel. It has two associated types. One for the normal messages and another one for errors. The [Message enum](https://github.com/dbeck/acto-rs/blob/0.5.2/src/lib.rs#L45) allows you to separate the normal processing from errors.

The `output` channel is a fixed sized queue. The `put` function receives a lambda function. This lambda receives a mutable reference to the next element in the queue. This allows very low latency messaging because all elements in the queue are preallocated.

### How can another element receive messages?

Let's create another silly actor for receiving the messages:

```rust
struct PrintGreatingSumActor {
  sum_received: usize,
}
```

([Code here.](https://github.com/dbeck/acto-rs-playground/blob/0.0.1/src/great_int.rs#L22))

To demonstrate how it changes its internal state I added a variable the sums up the integers it receives. The code for receiving messages is:

```rust
impl sink::Sink for PrintGreatingSumActor {

  type InputValue = usize;
  type InputError = String;

  fn process(&mut self,
             input: &mut ChannelWrapper<Self::InputValue, Self::InputError>,
             _stop: &mut bool)
  {
    if let &mut ChannelWrapper::ConnectedReceiver(ref mut _channel_id,
                                                  ref mut receiver,
                                                  ref mut _sender_name) = input
    {
      for m in receiver.iter() {
        match m {
          Message::Value(val) => {
            self.sum_received += val;
            println!("Hello {}, welcome. Sum is {}", val, self.sum_received);
          }
          Message::Error(position, err) => {
            println!("Error: {:?} at position: {:?}",err, position);
          }
          _ => {}
        }
      }
    }
  }
}
```

([Code here.](https://github.com/dbeck/acto-rs-playground/blob/0.0.1/src/great_int.rs#L26))

This is slightly more complicated than the sender was. I chose the [sink trait](https://github.com/dbeck/acto-rs/blob/0.5.2/src/elem/sink.rs#L4) which has a single input channel. There are two complications here that we need to handle:

1. The input channel may not be connected yet. For that reason I check if we received a [ConnectedReceiver channel](https://github.com/dbeck/acto-rs/blob/0.5.2/src/lib.rs#L96).
2. When we iterate through the messages, they can be [values, errors or acknowledgements](https://github.com/dbeck/acto-rs/blob/0.5.2/src/lib.rs#L45). I want to handle them differently.

Note that the iterator doesn't wait for messages. If no message is available the iterator returns `None` and breaks the `for` loop.

### What is missing from the example?

1. I haven't started the scheduler yet.
2. I haven't connected the two elements.
3. I haven't passed the actors to the scheduler.

Here is the code for all three:

```rust
use acto_rs::connectable::Connectable;

// create the scheduler
let mut sched = scheduler::new();

// start the scheduler
sched.start();

// specify the output queue size of the source element
let greater_queue_size = 2_000;

// create the source actor
let (greater_task, mut greater_output) =
  source::new( "SendGreatings",
               greater_queue_size,
               Box::new(SendGreatingsActor{last_sent:0}));;

// create the sink actor
let mut printer_task =
  sink::new( "PrintGreatingAndSum",
             Box::new(PrintGreatingSumActor{sum_received:0}));

// connect the sink to the source's output channel
printer_task.connect(&mut greater_output).unwrap();

// pass the two actors to the scheduler for being executed
let greater_id = sched.add_task(greater_task, SchedulingRule::OnExternalEvent).unwrap();
let _printer_id = sched.add_task(printer_task, SchedulingRule::OnMessage);

// notify the source element, which tells the scheduler to execute it
sched.notify(&greater_id).unwrap();

// stop the scheduler
sched.stop();
```

([Code here.](https://github.com/dbeck/acto-rs-playground/blob/0.0.1/src/great_int.rs#L55))

The above code does all three points. It creates and starts the scheduler. It creates the two actors. We need to specify the message queue size between the two actors. The message queue is always owned by the sender so the queue size is passed to the source element (actor) in this case. The next step is to connect the two actors. This is an unusual step which is quite different from other actor implementations. I explained the rationale behind this in a [previous post](/Rust-Actor-Library-Follow-up/). There are two main differences:

1. The actors needs to be connected before they are passed to the scheduler. The scheduler owns the actors, so we cannot access them directly from the outside. I feel this is quite natural in Rust.
2. The actors can only talk to other actors that they are previously connected. This is very different from Erlang/Elixir actors, where you can lookup an actor's pid if it was registered and send a message to it. My library cannot do that which is quite a serious restriction. On the positive side the messaging relations this way become explicit and easy to see who sends to whom.

When we pass the actors to the scheduler we need to tell it how to schedule them. The sink element is quite obvious: it should run when it received a new message, hence the `OnMessage` rule. For the source element we have multiple choices. If I chose the `Loop` rule it would be run in a loop and generate messages continuously. There could be use-cases when this is the sensible choice. I chose the `OnExternalEvent` rule instead, which runs the source actor when it is triggered by a `notify` call as above:

```rust
sched.notify(&greater_id).unwrap();
```

The `OnMessage` rule for the source would not make any sense, since it has no input channels. Another sensible choice would be to execute it periodically with the [Periodic rule](https://github.com/dbeck/acto-rs/blob/0.5.2/src/lib.rs#L70).

### Rust version

```text
rustc --version
rustc 1.12.1 (d4f39402a 2016-10-19)
```

The `acto-rs` library is tested on stable Rust and it uses only stable features.

### Feedbacks

If you have feedbacks or comments, please don't hesitate to ping me. They help me understanding use-cases I haven't thought about and viewpoints I didn't see. Please-please, I'd really appreciate them.
