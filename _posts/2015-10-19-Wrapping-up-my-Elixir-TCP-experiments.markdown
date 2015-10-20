---
published: true
layout: post
category: Elixir
tags: 
  - elixir
  - performance
  - TCP
  - socket
  - network
desc: Wrapping up my Elixir TCP experiments
keywords: "Elixir, TCP, Network, Performance, socket"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/observer-wrap-single-client.png
woopra: asyncmsgex
---

In this post I close my TCP small message experiment series in Elixir. Since my last post I further improved the small message server both in terms of performance and it became more Elixir-ish.

If you haven't followed the previous experiments then here are the links:

1. The first post was my most naive experiment to pass small messages from C++ to Elixir with an immediate acknowledgement. This led to [22k messages per second](/simple-TCP-message-performance-in-Elixir/).
2. The second in the series changed the protocol by allowing delayed acknowledement and combinining ACKs together. This resulted [100k messages per second](/Four-Times-Speedup-By-Throttling/) mainly because my suboptimal Elixir code.
3. By further improving the Elixir server I got [250k messages per second](/Over-Two-Times-Speedup-By-Better-Elixir-Code/).
4. The big speedup came when I stopped passing each message to a separate Elixir process. By calculating and sending the ACKs synchronously I achieved over [two million messages](/Passing-Millions-Of-Small-TCP-Messages-in-Elixir/).

In this post I recap what caused performance loss in my code and what made possible these improvements. The current version is doing over 3M messages per second. 

### Github repo

Previously I inlined the codes into my posts which I believe is not very convenient if you want to experiment. The github repo is available [here](https://github.com/dbeck/tcp_ex_playground). Feel free to clone.

I slightly renamed the files and the modules:

1. The [first experiment's](/simple-TCP-message-performance-in-Elixir/) files are named as ```RequestReply```
2. The [second](/Four-Times-Speedup-By-Throttling/) is in ```ThrottleAck```
3. The [thrird](/Over-Two-Times-Speedup-By-Better-Elixir-Code/) is in ```HeadRest```
4. The [fourth](/Passing-Millions-Of-Small-TCP-Messages-in-Elixir/) is in ```SyncAck```
5. The current experiment is in ```AsyncAck```

### Performance

With the latest changes I arrived to the 3M messages per second range:

```
elapsed usec=595899 avg(usec/call)=0.2979495 avg(call/msec)=3356.2735 avg(call/sec)=3356273.5
elapsed usec=608023 avg(usec/call)=0.3040115 avg(call/msec)=3289.3493 avg(call/sec)=3289349.3
elapsed usec=619510 avg(usec/call)=0.309755 avg(call/msec)=3228.3579 avg(call/sec)=3228357.9
elapsed usec=629900 avg(usec/call)=0.31495 avg(call/msec)=3175.1072 avg(call/sec)=3175107.2
elapsed usec=629148 avg(usec/call)=0.314574 avg(call/msec)=3178.9023 avg(call/sec)=3178902.3
elapsed usec=730798 avg(usec/call)=0.365399 avg(call/msec)=2736.7344 avg(call/sec)=2736734.4
elapsed usec=611692 avg(usec/call)=0.305846 avg(call/msec)=3269.6194 avg(call/sec)=3269619.4
elapsed usec=630911 avg(usec/call)=0.3154555 avg(call/msec)=3170.0192 avg(call/sec)=3170019.2
elapsed usec=613990 avg(usec/call)=0.306995 avg(call/msec)=3257.382 avg(call/sec)=3257382
elapsed usec=614098 avg(usec/call)=0.307049 avg(call/msec)=3256.8092 avg(call/sec)=3256809.2
elapsed usec=603122 avg(usec/call)=0.301561 avg(call/msec)=3316.0787 avg(call/sec)=3316078.7
elapsed usec=629041 avg(usec/call)=0.3145205 avg(call/msec)=3179.443 avg(call/sec)=3179443
elapsed usec=631746 avg(usec/call)=0.315873 avg(call/msec)=3165.8293 avg(call/sec)=3165829.3
elapsed usec=626637 avg(usec/call)=0.3133185 avg(call/msec)=3191.6405 avg(call/sec)=3191640.5
elapsed usec=639153 avg(usec/call)=0.3195765 avg(call/msec)=3129.1412 avg(call/sec)=3129141.2
elapsed usec=632023 avg(usec/call)=0.3160115 avg(call/msec)=3164.4418 avg(call/sec)=3164441.8
elapsed usec=624141 avg(usec/call)=0.3120705 avg(call/msec)=3204.4041 avg(call/sec)=3204404.1
elapsed usec=615717 avg(usec/call)=0.3078585 avg(call/msec)=3248.2455 avg(call/sec)=3248245.5
elapsed usec=626122 avg(usec/call)=0.313061 avg(call/msec)=3194.2657 avg(call/sec)=3194265.7
elapsed usec=629619 avg(usec/call)=0.3148095 avg(call/msec)=3176.5242 avg(call/sec)=3176524.2
```

Now I am using a separate [ACK responder process](https://github.com/dbeck/tcp_ex_playground/blob/master/lib/async_ack_handler.ex#L38-L59) because I figured out what caused the performance issue with that before in the second and third experiment.

### Using separate processes for concurrency

Using separate Elixir processes is a great way for concurrency. At the same time it is important to understand their performance implications. Sending a message to a process is not as lightweight as I thought. This takes time on the sender side which is far bigger than I expected. And the receiver's message queue can also be overwhelmed.

What I have read so far about Erlang and Elixir concurrency is pretty misleading. Authors seem to be too happy that they can implement a useless Fibonacci example by parallel processes. In practice one needs to be careful and measure the results.

In my third experiment I offloaded the ACK processing to a [timer and a Task process](https://github.com/dbeck/tcp_ex_playground/blob/master/lib/head_rest_handler.ex#L16-L34). Later I realized that passing large number of messages to a separate process is too expensive and I moved the [ACK generation into the same process](https://github.com/dbeck/tcp_ex_playground/blob/master/lib/sync_ack_handler.ex#L14-L30) that reads from the network. This gave me 9x performance improvement.

While I was happy with the improvement I started thinking about how to revert this and delegate the ACK processing to a separate process, because in a new experiment series I want to make the small message server distributed. So I decided not to pass each messages, but rather the original data blocks I read from network and offload the parsing to the separate process too. [This is what helped achieving the 3M messages](https://github.com/dbeck/tcp_ex_playground/blob/master/lib/async_ack_handler.ex#L61-L71).

```:observer.start``` load graph also looks healthier, because the new server utilizes the two cores in my laptop:

![Observing single client performance](/images/observer-wrap-single-client.png)

### Utilize Elixir binary pattern matching and reduce system calls

The message structure in this experiment has three parts:

- ID
- Payload size
- Payload

At my first naive attempt I did two reads to receive messages. First I read the two fixed length fields and then, based on the ```Payload size``` I read the payload. [This was very slow](https://github.com/dbeck/tcp_ex_playground/blob/master/lib/throttle_ack_handler.ex#L44-L62).

Then I decided to do as big reads as available from the network and try to parse whatever I had. This can be tricky because the data may be split between subsequent reads. [Solving this in Elixir](https://github.com/dbeck/tcp_ex_playground/blob/master/lib/head_rest_handler.ex#L55-L71) turned out to be very easy.
