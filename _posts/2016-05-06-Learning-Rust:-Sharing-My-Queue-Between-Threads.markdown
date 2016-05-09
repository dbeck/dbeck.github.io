---
published: true
layout: post
category: "Rust"
tags:
  - Rust
desc: "Learning Rust: Sharing My Queue Between Threads"
description: "Learning Rust: Sharing My Queue Between Threads"
keywords: "Rust, Learning, Experiment, Lock-Free, Queue, Lock free queue, multithreading"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF6937.JPG
woopra: rust_thrq
scalesmall_subscribe: false
---

This is the fourth episode of my Learning Rust posts. In the previous ones I developed a [lock-free queue](/Learning-Rust-Yet-Another-Lock-Free-Queue/) for sharing between a single producer and single consumer. The queue itself looked OK, except that it couldn't be shared between threads. Rust has strict checks about what and how can be shared and my implementation didn't comply to these rules.

In this post I focus on this missing part. I have two goals here:

1. make sure the code compiles when shared between threads
2. ensure that the queue can only be used by a single producer and single consumer

![multi threaded](/images/DSCF6937.JPG)

### CircularBuffer

As a reminder I copy here the data structure of the `CircularBuffer` that I want to share between threads:

```rust
struct CircularBuffer<T : Copy> {
  seqno       : AtomicUsize,        // the ID of the last written item
  data        : Vec<T>,             // (2*n)+1 preallocated elements
  size        : usize,              // n

  buffer      : Vec<AtomicUsize>,   // (positions+seqno)[]
  read_priv   : Vec<usize>,         // positions belong to the reader
  write_tmp   : usize,              // temporary position where the writer writes first
  max_read    : usize,              // reader's last read seqno
}
```

More information about the members, logic, implementation of this data structure can be found in my [previous post](/Learning-Rust-Yet-Another-Lock-Free-Queue/).

### Add Arc and UnsafeCell

I payed great attention to use the members of `CircularBuffer` in such a way to be thread safe, so no lock is needed if used by a single producer and a single consumer. In Rust this is not enough. I must explain this to the compiler otherwise it refuses to compile.

My first naive attempt, (which doesn't ensure the SPSC property neither compiles), uses Arc and UnsafeCell. `Arc` allows me to wrap the object in a thread safe reference counted pointer. With `UnsafeCell` I say that it is my business and responsibility that the internals of `CircularBuffer` can be modified through multiple references (so please-please compiler believe me...).

I don't think this is the right thing though. One of Rust's greatest strengths is not in use here: being able to reason about the thread safety through language constructs. But anyways, here is the code:

```rust
let shared = Arc::new(UnsafeCell::new(CircularBuffer::new(4, 0 as i32)));

let t = thread::spawn(move|| {
  for i in 1..1000000 {
    (*shared.get()).put(|v| *v = i);
  }
});

for _k in 1..1000 {
  let mut prev = 0;
  for i in (*shared.get()).iter() {
    if i < prev { panic!("invalid value read!"); }
    prev = i;
  }
}

t.join().unwrap();
```

This doesn't compile by the way, because I should be able to tell the compiler that I can safely share `core::cell::UnsafeCell<spsc::CircularBuffer<i32>>`:

```text
dbeck$ cargo run
   Compiling rpg v0.1.0 (file:///Users/dbeck/work/rust_playground)
src/spsc/mod.rs:203:13: 203:26 error: the trait `core::marker::Sync` is not implemented for the type `core::cell::UnsafeCell<spsc::CircularBuffer<i32>>` [E0277]
src/spsc/mod.rs:203     let t = thread::spawn(move|| {
                                ^~~~~~~~~~~~~
src/spsc/mod.rs:203:13: 203:26 help: run `rustc --explain E0277` to see a detailed explanation
src/spsc/mod.rs:203:13: 203:26 note: `core::cell::UnsafeCell<spsc::CircularBuffer<i32>>` cannot be shared between threads safely
src/spsc/mod.rs:203:13: 203:26 note: required because it appears within the type `[closure@src/spsc/mod.rs:203:27: 209:6 shared:alloc::arc::Arc<core::cell::UnsafeCell<spsc::CircularBuffer<i32>>>]`
src/spsc/mod.rs:203:13: 203:26 note: required by `std::thread::spawn`
error: aborting due to previous error
Could not compile `rpg`.

To learn more, run the command again with --verbose.
```

I made several attempts to add the `Sync` marker to `UnsafeCell<CircularBuffer<T>>` without any success. I gave up at the end, mainly because even if I could, the result wouldn't enforce the single producer-single consumer property. Without that my `CircularBuffer` is not thread safe.

### Implementation

I looked at the official [mpsc::channel implementation](https://github.com/rust-lang/rust/blob/master/src/libstd/sync/mpsc/mod.rs) and adapted it to my needs. (Note that, there already exists an SPSC channel in the standard lib, with different design decisions.)

The first thing I needed, is a function that creates the producer-consumer pair:

```rust
pub fn channel<T: Copy + Send>(size : usize,
                               default_value : T) -> (Sender<T>, Receiver<T>) {
    let a = Arc::new(UnsafeCell::new(CircularBuffer::new(size, default_value)));
    (Sender::new(a.clone()), Receiver::new(a))
}
```

Then I needed to wrap `Arc` and `UnsafeCell` into the `Sender` and the `Receiver`. Plus I had to tell Rust that it is safe to `Send` them between threads:

```rust
pub struct Sender<T: Copy> {
  inner: Arc<UnsafeCell<CircularBuffer<T>>>,
}

pub struct Receiver<T: Copy> {
  inner: Arc<UnsafeCell<CircularBuffer<T>>>,
}

unsafe impl<T: Copy> Send for Sender<T> { }
unsafe impl<T: Copy> Send for Receiver<T> { }
```

The last step is to wrap the `put` and `iter` functions into the `Sender` and `Receiver`.

```rust
impl<T: Copy + Send> Sender<T> {
  fn new(inner: Arc<UnsafeCell<CircularBuffer<T>>>) -> Sender<T> {
    Sender { inner: inner, }
  }

  pub fn put<F>(&mut self, setter: F) -> usize
    where F : FnMut(&mut T)
  {
    unsafe { (*self.inner.get()).put(setter) }
  }
}

impl<T: Copy + Send> Receiver<T> {
  fn new(inner: Arc<UnsafeCell<CircularBuffer<T>>>) -> Receiver<T> {
    Receiver { inner: inner, }
  }

  pub fn iter(&mut self) -> CircularBufferIterator<T> {
    unsafe { (*self.inner.get()).iter() }
  }
}
```

### SPSC

This code now compiles and works:

```rust
use std::thread;
use rpg::*;

let (mut tx, mut rx) = spsc::channel(7, 0 as i32);
let t = thread::spawn(move|| {
  for i in 1..1000000 {
    tx.put(|v| *v = i);
  }
});

for _k in 1..1000 {
  let mut prev = 0;
  for i in rx.iter() {
    if i < prev { panic!("invalid value read!"); }
    prev = i;
  }
}

t.join().unwrap();
```

So now I can share the queue between threads. The SPSC property is satisfied by the accessibility rules of the `Sender`, `Receiver` and `CircularBuffer` objects.

### Rust version

```
$ rustc --version
rustc 1.8.0 (db2939409 2016-04-11)
```

### Git repo

There is a [github repo](https://github.com/dbeck/rust_playground) for this experiment series. The source code of this experiment is [here](https://github.com/dbeck/rust_playground/blob/iter.4/src/spsc/mod.rs).

**Update**: The SPSC channel is now released as [lossyq crate](https://crates.io/crates/lossyq).

### Episodes of this series

1. [Closures](/Learning-Rust-Closures/)
2. [Iterator](/Learning-Rust-Iterator/)
3. [Yet Another Lock-Free Queue](/Learning-Rust-Yet-Another-Lock-Free-Queue/)
4. [Sharing My Queue Between Threads](/Learning-Rust-Sharing-My-Queue-Between-Threads/)
