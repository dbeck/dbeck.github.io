---
published: false
layout: post
category: "Rust"
tags:
  - Rust
desc: My First Steps In Rust
description: My First Steps In Rust
keywords: "Rust, Learning, Experiment"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF4696.JPG
pageid: rust_first_steps
scalesmall_subscribe: false
---

This is a highly subjective post about my first experiences in Rust. I have been reading tutorials, posts and docs for two months before I dared to write my first lines in Rust. The learning curve is very steep especially after experimenting with Elixir.

With Elixir I felt home from the very first moment and I could write programs instantly. With Rust I am constantly re-reading the manuals and still my first few lines took a day to write.

Still, I have good reasons for suspending my Elixir experiments for a while and focus on Rust. With Elixir I found myself missing the type enforcements and started implementing run-time type checks with [misusing function guards](/Scalesmall-W8-W10-Elixir-Tuples-Maps-and-ETS/) and writing tons of unit tests just to make sure I don't pass invalid objects around.

In Rust I have to write type-safe code from square one which made me afraid to jump in. Finally I bumped into kernel bypass networking concepts that made me curious for my `scalesmall` experiments. The libraries like [netmap](http://info.iet.unipi.it/~luigi/netmap/) and [DPDK](http://dpdk.org) are better be used in C/C++ and thus Rust.

![Rust at first](/images/DSCF4696.JPG)

### My first incorrect code

The code below aims for experimenting with traits and generics. The goal was to create two buffers holding different types and then put the two buffers into a vector and print them. This covers concepts that I know I will need later.

This took me a while to polish to this level but than I was stuck with en error that I couldn't understand and neither found a good explanation what it is about in my case:

```rust
pub fn testme() {

  trait Info {
    fn sz(&self) -> usize;
    fn print(&self);
  }

  struct Buffer<T> {
    buf: Vec<T>,
  }

  impl<T> Info for Buffer<T> {
    fn sz(&self) -> usize {
      self.buf.len()
    }

    fn print(&self) {
      for i in &self.buf {
        println!("trait: {:?}", i);
      }
    }
  }

  let int_buf    = Buffer { buf: vec![1,   2,   3] };
  let float_buf  = Buffer { buf: vec![1.1, 2.1, 3.1] };

  let buffers = vec![ &int_buf   as &Info,
                      &float_buf as &Info ];

  for i in &buffers {
    println!("sz: {}",i.sz());
    i.print();
  }
}
```

The error was:

```
dbeck$ cargo run
   Compiling actor v0.1.0 (file:///Users/dbeck/work/actor_rs)
src/x/mod.rs:22:33: 22:34 error: the trait `core::fmt::Debug` is not implemented for the type `T` [E0277]
src/x/mod.rs:22         println!("trait: {:?}", i);
                                                ^
<std macros>:2:25: 2:56 note: in this expansion of format_args!
<std macros>:3:1: 3:54 note: in this expansion of print! (defined in <std macros>)
src/x/mod.rs:22:9: 22:36 note: in this expansion of println! (defined in <std macros>)
src/x/mod.rs:22:33: 22:34 help: run `rustc --explain E0277` to see a detailed explanation
src/x/mod.rs:22:33: 22:34 note: `T` cannot be formatted using `:?`; if it is defined in your crate, add `#[derive(Debug)]` or manually implement it
src/x/mod.rs:22:33: 22:34 note: required by `core::fmt::Debug::fmt`
error: aborting due to previous error
Could not compile `actor`.

To learn more, run the command again with --verbose.
```

This was exactly the thing why I was afraid to jump in. The error tells me that my `T` type doesn't implement the Debug trait. It was clear that the error message is bogus and misleading since type `T` is either `i32` or `f32` which does implement the Debug trait otherwise I wouldn't be able to print those in a non-generic code.

It looks like the generic code's type `T` doesn't get resolved when the compiler arrives to the `println!` macro.

I went great lengths to try instantiating type `T` until I realized that it works very differently compared to C++.

### The correct code

Notice the two changes below:

```rust
pub fn testme() {

  // Change #1
  use std::fmt;

  trait Info {
    fn sz(&self) -> usize;
    fn print(&self);
  }

  struct Buffer<T> {
    buf: Vec<T>,
  }

  // Change #2
  impl<T: fmt::Debug> Info for Buffer<T> {
    fn sz(&self) -> usize {
      self.buf.len()
    }

    fn print(&self) {
      for i in &self.buf {
        println!("trait: {:?}", i);
      }
    }
  }

  let int_buf    = Buffer { buf: vec![1,   2,   3] };
  let float_buf  = Buffer { buf: vec![1.1, 2.1, 3.1] };

  let buffers = vec![ &int_buf   as &Info,
                      &float_buf as &Info ];

  for i in &buffers {
    println!("sz: {}",i.sz());
    i.print();
  }
}
```

I can't remember how I arrived to this solution since I made so many desperate attempts to fix it. When it worked, it clicked in perfectly. I don't need to *instantiate* the type, what I need is to give information to the compiler about the type. So I need to restrict type `T`, so the trait implementation only accepts types that actually implement the Debug trait. So the compiler was unhappy because of the *possibility* to pass types that doesn't implement the Debug trait and not what it was telling me: that I did pass a type that doesn't.

This makes sense and I like the way it is. Actually, I even prefer the Rust's way of generics compared to C++ templates. I am very positive about my next steps in Rust despite the unhelpful and misleading error messages, because I think once I understand how it works, I can reason about the code no matter what the compiler is complaining about.

### Rust version

```
$ rustc --version
rustc 1.7.0 (a5d1e7a59 2016-02-29)
```
