---
published: true
layout: post
category: "Rust"
tags:
  - Rust
desc: "Learning Rust: Yet Another Lock Free Queue"
description: "Learning Rust: Yet Another Lock Free Queue"
keywords: "Rust, Learning, Experiment, Lock-Free, Queue, Lock free queue"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF6901.JPG
woopra: rust_spsc
scalesmall_subscribe: false
---

The third episode of my Rust experiments further develops the `CircularBuffer` example. In the previous episodes I played with [closures](/Learning-Rust-Closures/) and [iterator for the CircularBuffer](/Learning-Rust-Iterator/).

This post changes the iterator to use slices rather then holding a reference to the CircularBuffer. (The slice based idea comes form [Shepmaster](http://stackoverflow.com/users/155423/shepmaster) from [this stack overflow discussion](http://stackoverflow.com/questions/36704115/how-to-express-lifetime-for-rust-iterator-for-a-container). Thank you.) The other change is that I added a level of indirection to support lock free operations.

![bite me](/images/DSCF6901.JPG)

### Design choices

This is yet another single publisher, single consumer queue. (I know there is one in the core library too.)

My queue implementation is based on a fix sized circular buffer. When the queue is full, the writer starts overwriting past elements. The writer doesn't get blocked, and the circular buffer won't be extended. This way the writer is not affected by the reader's speed and the buffer size doesn't grow without bounds. Memory allocation only happens when the buffer is created.

The reader can get an iterator to the queue and reading is done through this iterator. The read position is stored in the circular buffer, so data can only be delivered at most once.

Here the reader cannot wait for being notified when new elements arrived. I believe these are separate concerns:

- the notification
- the data storage

I only take care of the latter because I think once the data storage functionality is implemented, it is easy to add condition variables or any other way on top of this to help the reader waiting for new data.

### The new CircularBuffer

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

The `new` function creates the `CircularBuffer`:

```rust
impl <T : Copy> CircularBuffer<T> {
  fn new(size : usize, default_value : T) -> CircularBuffer<T> {

    if size == 0 { panic!("size cannot be zero"); }

    let mut ret = CircularBuffer {
      seqno      : AtomicUsize::new(0),
      data       : vec![],
      size       : size,
      buffer     : vec![],
      read_priv  : vec![],
      write_tmp  : 0,
      max_read   : 0,
    };

    // make sure there is enough place and fill it with the
    // default value
    ret.data.resize((size*2)+1, default_value);

    for i in 0..size {
      ret.buffer.push(AtomicUsize::new((1+i) << 16));
      ret.read_priv.push(1+size+i);
    }

    ret
  }
}
```

#### Writer

The `data` vector holds `2n+1` preallocated items. `n` items belong to the reader and `n+1` items belong to the writer. The ownership of who owns which elements are tracked by the `buffer`, `read_priv` and `write_tmp` members. The `buffer` vector represents the `CircularBuffer` where each element is composed of 16 bits of the `seqno` and the rest is a position to the `data` vector. The `write_tmp` element is also a position referring to the `data` vector. When the writer writes a new element:

- it writes to the `data` element pointed by `write_tmp`
- than it calculates `seqno` modulo `size`, which is the position in `buffer` which is going to be updated (new_pos)
- than `buffer[new_pos]` will be updated to hold `(write_tmp << 16) + (seqno % 0xffff)`
- finally `write_tmp` will be updated to the previous value of `buffer[old_pos] >> 16`
- (basically the positions of `write_tmp` and `buffer` will be swapped)

This design allows the writer to always write to a private area that is not touched by the reader and then it atomically swaps the `buffer[new_pos]` element over to the freshly written element. This allows writing without interfering with the reader.

```rust
impl <T : Copy> CircularBuffer<T> {
  fn put<F>(&mut self, setter: F) -> usize
    where F : FnMut(&mut T)
  {
    let mut setter = setter;

    // get a reference to the data
    let mut opt : Option<&mut T> = self.data.get_mut(self.write_tmp);

    // write the data to the temporary writer buffer
    match opt.as_mut() {
      Some(v) => setter(v),
      None    => { panic!("write tmp pos is out of bounds {}", self.write_tmp); }
    }

    // calculate writer flag position
    let seqno  = self.seqno.load(Ordering::SeqCst);
    let pos    = seqno % self.size;

    // get a reference to the writer flag
    match self.buffer.get_mut(pos) {
      Some(v) => {
        let mut old_flag : usize = (*v).load(Ordering::SeqCst);
        let mut old_pos  : usize = old_flag >> 16;
        let new_flag     : usize = (self.write_tmp << 16) + (seqno & 0xffff);

        loop {
          let result = (*v).compare_and_swap(old_flag,
                                             new_flag,
                                             Ordering::SeqCst);
          if result == old_flag {
            self.write_tmp = old_pos;
            break;
          } else {
            old_flag = result;
            old_pos  = old_flag >> 16;
          };
        };
      },
      None => { panic!("buffer index is out of bounds {}", pos); }
    }

    // increase sequence number
    self.seqno.fetch_add(1, Ordering::SeqCst)
  }
}
```

#### Reader

To read data one needs to obtain an iterator through the `iter()` function. This loops through the `buffer` in reverse order and atomically swaps the reader's own positions held by the `read_priv` vector with the position part of the `buffer` component. While looping it checks that the sequence number part of the `buffer` entry is the expected one. If not then it knows that the writer has flipped over, so the given element should be returned during the next iteration.

The result of this operation is that `read_priv` vector holds the pointers to the previously written elements and the reader gave its own elements to the writer in exchange, so the writer can write those, while the reader works with its own copies. The `iter()` function is implemented like this:

```rust
impl <T : Copy> CircularBuffer<T> {
  fn iter(&mut self) -> CircularBufferIterator<T> {
    let mut seqno : usize = self.seqno.load(Ordering::SeqCst);
    let mut count : usize = 0;
    let max_read : usize = self.max_read;
    self.max_read = seqno;

    loop {
      if count >= self.size || seqno <= max_read || seqno == 0 { break; }
      let pos = (seqno-1) % self.size;

      match self.read_priv.get_mut(count) {
        Some(r) => {
          match self.buffer.get_mut(pos) {
            Some(v) => {
              let old_flag : usize = (*v).load(Ordering::SeqCst);
              let old_pos  : usize = old_flag >> 16;
              let old_seq  : usize = old_flag & 0xffff;
              let new_flag : usize = (*r << 16) + (old_seq & 0xffff);

              if old_flag == (*v).compare_and_swap(old_flag, new_flag, Ordering::SeqCst) {
                *r = old_pos;
                seqno -=1;
                count += 1;
              } else {
                break;
              }
            },
            None => { panic!("buffer index is out of bounds {}", pos); }
          }
        },
        None => { panic!("read_priv index is out of bounds {}", count); }
      }
    }

    CircularBufferIterator {
      data    : self.data.as_slice(),
      revpos  : self.read_priv.as_slice(),
      count   : count,
    }
  }
}
```

The `CircularBufferIterator` is:

```rust
struct CircularBufferIterator<'a, T: 'a + Copy> {
  data   : &'a [T],
  revpos : &'a [usize],
  count  : usize,
}
```

The `revpos` slice is created from the reader's `read_priv` vector. It holds the pointers to the data that the reader can safely read. The iterator trait iterates through the `revpos` slice in reverse order:

```rust
impl <'_, T: '_ + Copy> Iterator for CircularBufferIterator<'_, T> {
  type Item = T;

  fn next(&mut self) -> Option<T> {
    if self.count > 0 {
      self.count -= 1;
      let pos : usize = self.revpos[self.count];
      Some(self.data[pos])
    } else {
      None
    }
  }
}
```

### Notes

The reader and the writer are both using the `buffer` vector. The reader tries to convince the writer to use its location while the reader processes the data previously written by the writer. To minimize contention the writer goes through the `buffer` in forward order and the `reader` works in the backward order.

To make this usable in real multithreaded programs I will need to dig into the `Send+Sync` realm. This will be the topic of my next post. May be I create my first crate afterwards?

### Rust version

```
$ rustc --version
rustc 1.8.0 (db2939409 2016-04-11)
```

### Git repo

I opened a [github repo](https://github.com/dbeck/rust_playground) for this experiment series. The source code of this experiment is [here](https://github.com/dbeck/rust_playground/blob/iter.3/src/spsc/mod.rs).
