---
published: true
layout: post
category: "ActorRS"
tags:
  - Rust
  - actor
  - concurrency
desc: "Rust Actor Library: First assorted thoughts"
description: "Rust Actor Library: First assorted thoughts"
keywords: "Rust, Actor, Concurrency"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF0458.JPG
woopra: actors_first
scalesmall_subscribe: false
---

I spent most of my spare time in the past few months on an [actor library for Rust](https://github.com/dbeck/acto-rs).

This is not a re-implementation of Erlang/Elixir/OTP. It has a lot narrower and different feature set. (I originally wanted a similar thing, but I changed course a few times, narrowed the scope and arrived to something different.)

![first](/images/DSCF0458.JPG)

```rust
[dependencies]
acto-rs = "0.5.2"
```

This actor library runs tasks with the help of fixed number of threads. If the scheduler is started without parameters (`start()`) then it starts only one thread. If more threads are desired then use `start_with_threads()`:

```rust
extern crate acto_rs;

fn first() {
  use acto_rs::scheduler;
  let mut sched = scheduler::new();
  sched.start_with_threads(4);
  sched.stop();
}
```

For this to make any sense we will need to add tasks. Tasks must implement the [Task trait](https://github.com/dbeck/acto-rs/blob/master/src/lib.rs#L83):

```rust
pub trait Task {
  fn execute(&mut self, stop: &mut bool);
  fn name(&self) -> &String;
  fn input_count(&self) -> usize;
  fn output_count(&self) -> usize;
  fn input_id(&self, ch_id: ReceiverChannelId) -> Option<(ChannelId, SenderName)>;
  fn input_channel_pos(&self, ch_id: ReceiverChannelId) -> ChannelPosition;
  fn output_channel_pos(&self, ch_id: SenderChannelId) -> ChannelPosition;
}
```

The execution of the tasks is controlled by a [SchedulingRule](https://github.com/dbeck/acto-rs/blob/master/src/lib.rs#L67).

### Tasks

Tasks can have typed input and output channels. However it is possible to schedule a tasks without any channels. This doesn't make much sense but shows the minimum:

```rust
// a very simple task with a counter only
struct NakedTask {
  // to help the Task trait impl
  name : String,
  // state
  count : usize,
}
```

Here is the implementation of the Task trait:

```rust
impl Task for NakedTask {
  // execute() runs 3 times and after it sets the stop flag
  // which tells the scheduler, not to execute this task anymore
  fn execute(&mut self, stop: &mut bool) {
    self.count += 1;
    println!("- {} #{}", self.name, self.count);
    if self.count == 3 {
      // three is enough
      *stop = true;
    }
  }

  fn name(&self) -> &String { &self.name }

  // zero / None values, since NakedTask has
  // no input or output channels
  fn input_count(&self) -> usize { 0 }
  fn output_count(&self) -> usize { 0 }
  fn input_id(&self, _ch_id: ReceiverChannelId)
    -> Option<(ChannelId, SenderName)> { None }
  fn input_channel_pos(&self, _ch_id: ReceiverChannelId)
    -> ChannelPosition { ChannelPosition(0) }
  fn output_channel_pos(&self, _ch_id: SenderChannelId)
    -> ChannelPosition { ChannelPosition(0) }
}
```

Finally we need to pass instance(s) of NakedTask to a scheduler:

```rust
pub fn run_naked() {
  // - create a scheduler
  // - add a recurring task
  // - stop the scheduler after 4 seconds
  let mut sched = scheduler::new();
  sched.start();
  sched.add_task(
    Box::new(NakedTask{name:String::from("RunningNaked"), count:0}),
    SchedulingRule::Periodic(PeriodLengthInUsec(1_000_000))).unwrap();
  thread::sleep(time::Duration::from_secs(4));
  sched.stop();
}
```

([Github repository](https://github.com/dbeck/acto-rs-playground/blob/master/src/naked.rs) for playing around with `acto-rs`.)

### Periodic, Loop and OnExternalEvent

NakedTask has little practical use however it can demonstrate 2 other `SchedulingRule`s too. The `Periodic` is shown above, run 3 times and wait a second in between. The `Loop` rule is even more useless, its main feature is to increase electricity bill:

```rust
pub fn increase_my_bill() {
  let mut sched = scheduler::new();
  sched.start();
  sched.add_task(
    Box::new(NakedTask{name:String::from("IncreaseBill"), count:0}),
    SchedulingRule::Loop).unwrap();
  thread::sleep(time::Duration::from_secs(1));
  sched.stop();
}
```

In general `Loop` can be used for Tasks need to run continuously in a round-robin fashion.

The `OnExternalEvent` is slightly more usable because it allows running a Tasks triggered by an external event. This is a good candidate for MIO integration:

```rust
pub fn trigger_me() {
  let mut sched = scheduler::new();
  sched.start();
  let task_id = sched.add_task(
    Box::new(NakedTask{name:String::from("TriggerMe"), count:0}),
    SchedulingRule::OnExternalEvent).unwrap();
  // notify(..) wakes up the task identified by task_id
  sched.notify(&task_id).unwrap();
  sched.stop();
}
```

### With channels

If a Task happen to have channels and able to talk to other Tasks then it becomes more interesting. To create such tasks I added a few helpers. Depending on the number and type of input/output channels, different helpers are available.

A simple [Source](https://github.com/dbeck/acto-rs/blob/0.5.2/src/elem/source.rs#L5) task for example has one output channel. This channel can pass [Messages](https://github.com/dbeck/acto-rs/blob/0.5.2/src/lib.rs#L45) which can be a value or an error or an acknowledgement.

For the `Source` trait I added a convenience [new function](https://github.com/dbeck/acto-rs/blob/0.5.2/src/elem/source.rs#L15) that creates an object that conforms the Task trait and holds the channel handles. This simplifies creating a source element.

Similarly I created helpers for:

- a [Sink element](https://github.com/dbeck/acto-rs/blob/0.5.2/src/elem/sink.rs#L4) that has a single input channel
- a [Filter element](https://github.com/dbeck/acto-rs/blob/0.5.2/src/elem/filter.rs#L7) that has a single input and a single output channel of possibly different types, which allows translating between different message types
- a [YSplit element](https://github.com/dbeck/acto-rs/blob/0.5.2/src/elem/ysplit.rs#L7) that has an input channels and two possibly different output channels, which allows emitting different messages
- a [YMerge element](https://github.com/dbeck/acto-rs/blob/0.5.2/src/elem/ymerge.rs#L7) that may receive messages on two input channels of possibly different type and emits messages on an output channel
- a [Scatter element](https://github.com/dbeck/acto-rs/blob/0.5.2/src/elem/scatter.rs#L7) that has one input channel and possibly many output channels of the same type
- a [Gather element](https://github.com/dbeck/acto-rs/blob/0.5.2/src/elem/gather.rs#L7) that can have many input channels of the same type and one output channel

### Closing thoughts

This post became a lot longer than I wanted. In a next post I will give examples for using the helpers to create elements that are actually passing messages to each other.

### Rust

This library only needs stable Rust and probably works with nightly too.

```
rustc --version
rustc 1.12.1 (d4f39402a 2016-10-19)
```

### Update

I have written a [follow up post](/Rust-Actor-Library-Follow-up/) based on the feedbacks. 
