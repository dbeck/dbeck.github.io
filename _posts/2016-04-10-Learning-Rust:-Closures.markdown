---
published: false
layout: post
category: "Rust"
tags:
  - Rust
desc: "Learning Rust: Closures"
description: "Learning Rust: Closures"
keywords: "Rust, Learning, Experiment"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF6998.JPG
pageid: rust_closures
scalesmall_subscribe: false
---

I start a Rust learning series of posts, of which this is the first episode. I want to take advantage of being a beginner, so I can help people who bump into similar issues like I do. These issues are largely caused by my missing knowledge and not because there is any problem with the language.

Rust is a fantastic one. Every time the compiler doesn't allow me to do something I realize that it is just better be done that way. C++ allows me to write sloppy code, that Rust doesn't. So when I fix my Rust code I am also improving my generic programming skills.

The series start with a naive generic circular buffer and I think a few more posts will follow this topic.

![circular buffer](/images/DSCF6998.JPG)

### Yet another circular buffer

I want a fixed sized circular buffer that:

1. supports a single publisher and single subscriber
2. doesn't do dynamic allocation
3. overwrites old elements when the buffer is full

It deserves an own post why I like this construct as opposed to block the publisher or growing the buffer.

#### Data structure

```rust
struct CircularBuffer<T : Copy> {
  seqno : usize,
  data  : Vec<T>,
}
```

The `seqno` sequence number tells where the writer position is. The `data` vector holds the data. The idea is that new elements overwrite an existing element in the data vector. This will be initialized at construction time by filling the entries with a default value:

```rust
impl <T : Copy> CircularBuffer<T> {
  fn new(size : usize, default_value : T) -> CircularBuffer<T> {

    if size == 0 { panic!("size cannot be zero"); }

    let mut ret = CircularBuffer {
      seqno : 0,
      data  : vec![],
    };

    // make sure there is enough place and fill it with the
    // default value
    ret.data.resize(size, default_value);
    ret
  }
}
```

#### Publisher

Here is the publisher code:

```rust
impl <T : Copy> CircularBuffer<T> {
  fn put<F>(&mut self, setter: F) -> usize
    where F : Fn(&mut T)
  {
    // calculate where to put the data
    let pos = self.seqno % self.data.len();

    // get a reference to the data
    let mut opt : Option<&mut T> = self.data.get_mut(pos);

    // make sure the index worked
    match opt.as_mut() {
      Some(v) => setter(v),
      None    => { panic!("out of bounds {}", pos); }
    }

    // increase sequence number
    self.seqno += 1;
    self.seqno
  }
}
```

I had multiple options for the interface. I could have created one that:

1. returns a writable reference to an entry in the buffer
2. (the user places the next element into the referenced location)
3. the user tells the circular buffer that the copy is done, so increment the sequence number

I felt this is too fragile and complicated. So I decided to let the user pass in a closure that receives a writable reference to an element in the buffer and it is the closure that copies in the data. (Hence the title of this article.)

#### How to use it

```rust
#[test]
fn can_put() {
  // two element buffer
  let mut x = CircularBuffer::new(2, 0 as i32);

  // fill in an element
  x.put(|v| *v = 1);
}
```

#### My unlucky experiment

I was glad to reach this point, because my other tests showed that the code does what I wanted. Then I tried passing in a closure that increments a counter which was not as shiny:

```rust
#[test]
fn can_put_with_env() {
  let mut x = CircularBuffer::new(1, 0 as i32);
  let mut y = 0;
  let my_fn = |v : &mut i32| {
    *v = y;
    y += 1;
  };
  x.put(my_fn);
}
```

I received this error:

```
src/simple/mod.rs:94:5: 94:15 error: the trait `for<'r> core::ops::Fn<(&'r mut i32,)>` is not implemented for the type `[closure@src/simple/mod.rs:90:15: 93:4 y:&mut i32]` [E0277]
src/simple/mod.rs:94   x.put(my_fn);
                         ^~~~~~~~~~
src/simple/mod.rs:94:5: 94:15 help: run `rustc --explain E0277` to see a detailed explanation
error: aborting due to previous error
```

As it turned out I was unfortunate that I stored the closure into a variable and thus arriving to the above error, because the message has put me on a completely wrong track. If I would have tried the one below, then I could have seen a different error that is clear about what to do:

```rust
#[test]
fn can_put_with_env() {
  let mut x = CircularBuffer::new(1, 0 as i32);
  let mut y = 0;
  x.put(|v| { *v = y; y += 1; });
}
```

The error is this:

```
src/simple/mod.rs:90:23: 90:29 error: cannot assign to data in a captured outer variable in an `Fn` closure [E0387]
src/simple/mod.rs:90   x.put(|v| { *v = y; y += 1; });
                                           ^~~~~~
src/simple/mod.rs:90:23: 90:29 help: run `rustc --explain E0387` to see a detailed explanation
src/simple/mod.rs:90:9: 90:32 help: consider changing this closure to take self by mutable reference
src/simple/mod.rs:90   x.put(|v| { *v = y; y += 1; });
                             ^~~~~~~~~~~~~~~~~~~~~~~
```

The explain message tells me that I should have used `FnMut` instead of `Fn` if I want to modify the captured environment.

#### Fixed code

I added another method to the impl:

```rust
impl <T : Copy> CircularBuffer<T> {

  fn put_mut<F>(&mut self, mut setter: F) -> usize
    where F : FnMut(&mut T)
  {
    // calculate where to put the data
    let pos = self.seqno % self.data.len();

    // get a reference to the data
    let mut opt : Option<&mut T> = self.data.get_mut(pos);

    // make sure the index worked
    match opt.as_mut() {
      Some(v) => setter(v),
      None    => { panic!("out of bounds {}", pos); }
    }

    // increase sequence number
    self.seqno += 1;
    self.seqno
  }
}
```

The test now works:

```rust
#[test]
fn can_put_with_env() {
  let mut x = CircularBuffer::new(1, 0 as i32);
  let mut y = 0;
  x.put(|v| { *v = y; y += 1; });
}
```

### More information

I found [this post](http://huonw.github.io/blog/2015/05/finding-closure-in-rust/) from Huon Wilson that helped me better understand closures in Rust. I warmly recommend his other posts too. I think the [Finding Closure in Rust](http://huonw.github.io/blog/2015/05/finding-closure-in-rust/) post is a great complement to the official Rust documentation about Closures.

### Rust version

```
$ rustc --version
rustc 1.7.0 (a5d1e7a59 2016-02-29)
```

### Git repo

I opened a [github repo](https://github.com/dbeck/rust_playground) for this experiment series.

### Episodes of this series

1. [Closures](/Learning-Rust-Closures/)
2. [Iterator](/Learning-Rust-Iterator/)
3. [Yet Another Lock-Free Queue](/Learning-Rust-Yet-Another-Lock-Free-Queue/)
4. [Sharing My Queue Between Threads](/Learning-Rust-Sharing-My-Queue-Between-Threads/)
