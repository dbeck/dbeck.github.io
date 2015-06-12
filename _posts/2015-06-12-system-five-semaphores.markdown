---
published: true
layout: post
category: programming
tags: 
  - semaphore
---


### Interesting beast

System V semaphores are here for decades. Few days ago when I was looking for options for inter process communication I bumped into it again. Fortunately enough I picked up [Stevens' Unix Network Programming Vol #2](http://www.kohala.com/start/unpv22e/unpv22e.html) from the bookshelf rather then relying on a search engine. Stevens does a great job at explaining what they are and what is their API and this explanation is badly needed.

I am not going to write about what a semaphore is. Search engines and Wikipedia are great resources on that. I will focus on this specific instrument.

If you are looking for a conventional semaphore functionality then System V semaphores are just bad:

- the number of semaphores in the system is limited
- the semaphore naming is awkward
- the POSIX standard doesn't define timed waiting

Funny to say that System V semaphores are non-traditional semaphores for something that is here for so long. Why non-traditional?:

- the basic building block of a System V semaphore is a semaphore _set_ rather than a single value
- we can do _atomic_ operations on these sets
- we can both wait for values to reach a threshold or to become zero

### What all these bring to us

Apart from being a (not very compelling) semaphore we can create system wide counters with semaphores. Users can wait for them. My use case is that I wanted a local, non-distributed queue where the messages are identified by their stream position, just like [Kafka](http://kafka.apache.org/documentation.html).

An item in the semaphore set can only hold up to 32767 values which is not very big for my local queue. This is where value sets (equals System V semaphore) and atomic operations come into the picture. 

### Simple counter

### Counter with overflow
