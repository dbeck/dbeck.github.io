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

As a demonstration of the atomic operations let's create a simple counter that always increases and others can wait for these to happen. 

The publisher creates the semaphore, resets to zero and increases the value.

    // create the semaphore
    key_t semkey = ftok("/tmp/whatever", 1);
    int semaphore_id = semget(semkey, 1, 0600|IPC_CREAT );
    
    // reset initial value
    short zero = 0;
    semctl(semaphore_id,0,SETALL,&zero);
    
    // increase the counter by 1
    struct sembuf ops[1];
    ops[0].sem_num  = 0;
    ops[0].sem_op   = 1;
    ops[0].sem_flg  = 0;
    semop(semaphore_id,ops,1);
    
Nothing special so far. Let's look at the subscriber code. It opens the counter and wait for its increase.

    // open semaphore
    key_t semkey = ftok("/tmp/whatever", 1);
    int semaphore_id = semget(semkey, 1, 0600 );
    
    // wait for the counter to be greater than previous_value
    short previous_value = 0;
    
    struct sembuf ops[2];
    ops[0].sem_num  = 0;
    ops[0].sem_op   = -1*(previous_value+1);
    ops[0].sem_flg  = 0;
    ops[1].sem_num  = 0;
    ops[1].sem_op   = (previous_value+1);
    ops[1].sem_flg  = 0;
    
    semop(semaphore_id,ops,2);

This is the power of atomic operations. I can wait for the value to be _previousvalue+1_ in the first operation. This first operation decreases the value but that doesn't bother me much, because I know I can add it back in the next operation.

This is the plus over POSIX semaphores. However there is a not so minor issue here. The maximum value of this counter is 32767. Fortunately this can be solved by the set nature of the semaphore and the atomic operations.

### Counter with overflow
