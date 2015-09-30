---
published: true
layout: post
category: programming
tags: 
  - slowdata
  - bigdata
desc: Price of Being Distributed
keywords: "C++, Linux, Unix, Queue, Kafka, BigData, Hadoop, Apache, SlowData, Performance"
woopra: distribprice
---


### BigData
I am watching how new and new BigData projects came from nowhere and slowly changing the whole computing landscape. I see a great value in this and I see great ideas coming from these projects. One of my personal favourite is [Kafka](http://kafka.apache.org). I like its simplicity and the way they found a balance between having a good abstraction over queues and still being fast and scalable. 
The other good outcome of these projects is distributed computing became easy. Now everyone can imagine a new kind of scalable service by selecting a few projects and putting these pieces together. This is also great. Sometimes however I feel there may be too many people designing new distributed systems.
### Streaming + Batch architecture
More and more people feel the high latency of Hadoop + MapReduce family too limiting and new designs are cropping up. A typical way of thought is to use a scalable queue to store high volume incoming data. Then use a distributed stream processor to post process the data and use a scalable distributed storage to sink the data into a data lake in parallel to the stream processing. We have ticking, streaming data and historical data at the same time. Typical building blocks are Kafka / RabitMQ, Storm, Hadoop/HDFS, Redis, Cassandra, Hive, etc...
I notice all components are scalable, fault-tolerant and distributed here. What can go wrong then? Nothing in fact.
### Distributed queue performance
I am very much interested in the performance of these systems and my approach was to see the performance of each stage. When I looked into the distributed queue performance I stopped looking further. Few people published comparisons between distributed and persistent queues and the results were shocking to me. [Here is one](http://www.warski.org/blog/2014/07/evaluating-persistent-replicated-message-queues/) for example. I found most measurements do 1-10k messages per second for a distributed queue on a single computer and they start scaling by adding new computers. I believe these are great results and I am sure there are use-cases when these are fine.
### Local persistent queue performance
I was very much interested in seeing how fast a local, persistent queue would be in comparison. Just give up fault tolerance, scalability and distributed computing and focus on this core feature. I wrote this [piece](https://github.com/starschema/virtdb-queue). The [simple_queue](https://github.com/starschema/virtdb-queue/blob/master/src/queue/simple_queue.hh) model has a single publisher and potentially multiple subscribers. The publisher publishes to a mmapped file and notifies the subscribers through a System V semaphore set. No fancy shared memory setup or compression, just write that data into a file and notify others.
Here is the shock: this extremely simple approach can do 10 million 8 byte messages per second.
### Questions
I did know that the local queue is gonna be faster. What I didn't know is the ratio. I am not doing fault tolerance neither scalability by adding new computers. This part is clear.
What is interesting is that the persistent local queue does at least 1000 times faster, so assuming linear scalability (by a factor of 1) on the scalable software you would need to add at least 1000 computers to keep up.
Let's bring this argument one step further and go back to Lambda architecture. We have a big pile of distributed and scalable components each doing their scalable and distributed functionality on their own. What if we would have a pile of non-distributed, but 1000x faster local components instead, doing their job locally and have one single component responsible for managing scalability and fault tolerance. How would that perform?
Unfortunately we don't have that many of these local components. We have [RocksDB](http://rocksdb.org) for example. Hope I will find more...
### Architecture notes
The reason I designed our local queue this way is not by accident. Once I read about the design decisions in Varnish Cache and very recently I bumped into [this article](https://www.varnish-cache.org/trac/wiki/ArchitectNotes). I have the feeling that we are doing the same mistakes with BigData components that we did before with local components. So I wanted to experiment with the idea of utilizing the OS cache for storing the enqueued components and stopped myself of imagining any sophisticated shared memory queues and intelligent buffer management and so on. This is the first software that I have written with this in mind but not the last one.
