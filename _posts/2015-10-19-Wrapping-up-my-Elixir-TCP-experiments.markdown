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

Previously I inlined the codes into my posts which I believe is not very convenient if you want to experiment. The github repo is available [here](https://github.com/dbeck/tcp_ex_playground). Feel free to clone or fork.

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

### UPDATE: Linux performance

I only tested on my Macbook Air which I thought is OK as long as my goal is to improve my Elixir skills by polishing this experiment. Thanks to Panagiotis PJ Papadomitsos' comments I checked this on a spare Linux box too. This is around 7 years old box running Linux non-virtualized. I have a few other boxes at work but they all running VMware VMs, so as per Panagiotis' suggestion may not be the best for these tests.

**Here are the results:**

<p>
<table>
  <tr>
    <th>&nbsp;</th>
    <th>RequestReply</th>
    <th>Throttle</th>
    <th>HeadRest</th>
    <th>SyncAck</th>
    <th>AsyncAck</th>
  </tr>
  <tr><td>Deafult Settings</td><td>20k</td><td>30k</td><td>78k</td><td>1380k</td><td>780k</td></tr>
  <tr><td>+K true</td><td>19k</td><td>30k</td><td>78k</td><td>1380k</td><td>780k</td></tr>
  <tr><td>+K false +sbwt none</td><td>20k</td><td>30k</td><td>80k</td><td>1400k</td><td>790k</td></tr>
  <tr><td>+K false +sbwt none +swt very_high</td><td>20k</td><td>30k</td><td>78k</td><td>1380k</td><td>790k</td></tr>
  <tr><td>+K false +sbwt none +swt very_low</td><td>20k</td><td>30k</td><td>82k</td><td>1390k</td><td>810k</td></tr>
</table>
</p>

**Here is the cpuinfo for this Linux machine:**

```
processor	: 0
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Genuine Intel(R) CPU           U2300  @ 1.20GHz
stepping	: 10
microcode	: 0xa04
cpu MHz		: 1199.990
cache size	: 1024 KB
physical id	: 0
siblings	: 2
core id		: 0
cpu cores	: 2
apicid		: 0
initial apicid	: 0
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts rep_good nopl aperfmperf pni dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm xsave lahf_lm dtherm tpr_shadow vnmi flexpriority
bogomips	: 2399.98
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 1
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Genuine Intel(R) CPU           U2300  @ 1.20GHz
stepping	: 10
microcode	: 0xa04
cpu MHz		: 1199.990
cache size	: 1024 KB
physical id	: 0
siblings	: 2
core id		: 1
cpu cores	: 2
apicid		: 1
initial apicid	: 1
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts rep_good nopl aperfmperf pni dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm xsave lahf_lm dtherm tpr_shadow vnmi flexpriority
bogomips	: 2399.98
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:
```

This CPU is way slower than my Mac's so I don't want to compare the absolute numbers. The main takeway for me is that the performance is dominated by the relation of the network performance versus the CPU power. This could have been obvious but the actual numbers are very interesting. My latest AsyncAck code that performs best on Mac becomes second on the slow Linux box. The Erlang VM settings on the other hand made little difference, I guess because the CPU power was too slow for these settings to actually matter.

I start to have the feeling that writing performant Elixir code, one also need to think about the hardware where it is going to run. At least for this kind of networking code. I am saying this because the only difference between the SyncAck and AsyncAck code is that I have put the Ack processing on a separate process for which the CPU was not enough in this box. So to max out this Linux box I'd need to make a software architecture decision too. This is pretty much in contrast to what I expected. My naive feeling was that a well written Elixir code would run equally well on any computer / OS, only that the relative performance of the boxes would differ.

### UPDATE2: FreeBSD on EC2

I couldn't resist to do another experiment on a c4.large EC2 instance, running FreeBSD 10. Here are the numbers:

<p>
<table>
  <tr>
    <th>&nbsp;</th>                   
    <th>RequestReply</th> 
    <th>Throttle</th> 
    <th>HeadRest</th>
    <th>SyncAck</th>
    <th>AsyncAck</th>
  </tr>
  <tr>
    <td>Deafult Settings</td>
    <td>26k</td>
    <td>150k</td>   
    <td>302k</td>
    <td>2600k</td>
    <td>2400k</td>
  </tr>
  <tr>
    <td>+K true</td>
    <td>26k</td>
    <td>155k</td>
    <td>305k</td>
    <td>2600k</td>
    <td>2200k</td>
  </tr>
  <tr>
    <td>+K false</td>
    <td>26k</td>
    <td>154k</td>
    <td>305k</td>
    <td>2500k</td>
    <td>2180k</td>
  </tr>
  <tr>
    <td>+K false +sbwt none</td>
    <td>26k</td>
    <td>154k</td>
    <td>305k</td>
    <td>2500k</td>
    <td>2400k</td>
  </tr>
  <tr>
    <td>+K false +sbwt none +swt very_high</td>
    <td>26k</td>
    <td>154k</td>
    <td>308k</td>
    <td>2500k</td>
    <td>2200k</td>
  </tr>
  <tr>
    <td>+K false +sbwt none +swt very_low</td>
    <td>26k</td>
    <td>155k</td>
    <td>308k</td>
    <td>2550k</td>
    <td>2300k</td>
  </tr>
</table>
</p>

Interesting to see how a faster CPU and a different OS impacts the numbers. Just like on Linux, my separate ACK process that worked well in Mac OSX, hurts performance here.

uname -a: ```FreeBSD ip-172-30-0-199 10.2-RELEASE FreeBSD 10.2-RELEASE #0 r286666: Wed Aug 12 15:26:37 UTC 2015 root@releng1.nyi.freebsd.org:/usr/obj/usr/src/sys/GENERIC```
