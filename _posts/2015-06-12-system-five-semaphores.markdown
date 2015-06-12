---
published: true
layout: post
category: programming
tags: 
  - semaphore
---



### Interesting beast

System V semaphores are here for decades. Few days ago when I was looking for options for inter process communication I bumped into it again. Fortunately enough I picked up [Stevens' Unix Network Programming Vol #2](http://www.kohala.com/start/unpv22e/unpv22e.html) from the bookshelf rather then relying on a search engine. Stevens does a great job at explaining what they are and what is their API and this explanation is badly needed.

I am not going to write about what a generic semaphore is. Search engines and Wikipedia are great resources on that. I will focus on this specific instrument.

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

This is the power of atomic operations. I can wait for the value to be _previous_value+1_ in the first operation. This first operation decreases the value but that doesn't bother me much, because I know I can add it back in the next operation, so the subscriber won't visibly change the counter's value but still it could wait for it to reach at least _previous_value+1_.

This is the plus over POSIX semaphores. There is a not so minor issue though. The maximum value of this counter is 32767. Fortunately this can be solved by the set nature of the semaphore and the atomic operations.

### Counter with overflow

To overcome the limitation of my previous counter I will use a semaphore with two values in the set.

The trick is in the publisher part. I will use the set's values as a base 10.000 integer. The first value in the set is the least significant and the second is the most significant value.

    // create the semaphore
    key_t semkey = ftok("/tmp/whatever", 1);
    int semaphore_id = semget(semkey, 2, 0600|IPC_CREAT );
    
    // reset initial value
    short zeros[2] = {0, 0};
    semctl(semaphore_id,0,SETALL,zeros);
    
    // increase the counter by 1 and handle overflow in one step
    struct sembuf ops[3];
    ops[0].sem_num  = 0;
    ops[0].sem_op   = 1;
    ops[0].sem_flg  = 0;
    ops[1].sem_num  = 0;
    ops[1].sem_op   = -10000;
    ops[1].sem_flg  = IPC_NOWAIT;    
    ops[2].sem_num  = 1;
    ops[2].sem_op   = 1;
    ops[2].sem_flg  = 0;
    if( semop(semaphore_id,ops,3) < 0 )
    {
      // no overflow needed
      semop(semaphore_id,ops,1);
    }

I presume I have one single publisher and noone else changes the value so there is no race condition between the overflow and non-overflow part. The reason this works is that the semaphore operation is atomic. The NOWAIT flag tells the system to reduce the least significant counter if theres is an overflow over 10000 if possible. Otherwise it returns an error which leads to the _no overflow case_. Shiny.

The subscriber part is not as shiny as the publisher. The problem with this solution is that the subscriber neeeds to know what is the value to wait for. For example if the subscriber thinks the counter is 9998 and waits for it to be 9999, but the publisher is lot faster and the value became 10002 at the meantime then the subsciber will wait for long.

The 10002 in our example is {2,1} in my semaphore value terms.

On Linux there is a non standard GNU extension to the System V interface that comes handy in this case called _semtimedop_. On other systems like Mac OSX this is not available.

    // open semaphore
    key_t semkey = ftok("/tmp/whatever", 1);
    int semaphore_id = semget(semkey, 2, 0600 );
    
    // initialize prev values
    uint32_t previous_value = 9998;
    short previous_value_set[2] = {
      previous_value%1000,
      previous_value/1000
    };
    
    // wait for the counter
    while( (previous_value_set[0]+
            10000*previous_value_set[1]) <= previous_value )
    {
      
      // timed wait on the least significant value only
      struct sembuf ops[2];
      ops[0].sem_num  = 0;
      ops[0].sem_op   = -1*(previous_value_set[0]+1);
      ops[0].sem_flg  = 0;
      ops[1].sem_num  = 0;
      ops[1].sem_op   = previous_value_set[0]+1;
      ops[1].sem_flg  = 0;

      // 20 ms
      struct timespec ts = { 0, 20*1000000 };
      semtimedop(semaphore_id,ops,2,&ts);
    
      semctl(semaphore_id,0,GETALL,previous_value_set);
    }

It is fairly easy to extend this counter to larger values by adding more values into the semaphore set and do more semaphore operations in the sembuf array.
