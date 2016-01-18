---
published: true
layout: post
category: Other
tags: 
  - reliable
  - performance
  - TCP
  - reliability
desc: Experimental protocol for passing large number of small messages reliably
description: Experimental protocol for passing large number of small messages reliably
keywords: "TCP, Network, Performance, socket, experiment"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/experimentalprotocol_combine2_red3.png
woopra: relmsgexp
---

In my previous Elixir experiments {[1](/Four-Times-Speedup-By-Throttling/), [2](/Passing-Millions-Of-Small-TCP-Messages-in-Elixir/)} I palyed a bit with relaxing the Request/Reply pattern. Replies were only used to acknowledge the Requests and I allowed these ACKs to be delayed and combined into fewer messages. The motivation for doing that is to allow the sender to continue without immediate acknowledgement. The sender can still decide to wait for the ACKs thus revert to the original Request/Reply pattern.

In this post I would like to extend the previous solution to add reliability by involving more peers.

### The original, non-reliable pattern

The Request/Reply pattern's biggest drawback is that the various overheads are piling up and reduce message rates:

![Request reply pattern](/images/RequestReply.png)

The Throttled Reply pattern solves this problem by allowing to acknowledge multiple messages in one step:

![Throttled reply](/images/ThrottledReply.png)

### Motivation and goals

My #1 goal is to give more control to the sender. By deciding how many and what types of acknoledgement the sender needs/requires to continue, it effectively controls the system's reliability and performance. I want the sender to be able to make these tradeoffs, even at the message level.

The other competing goal I have is to make the receiver side efficient. Meaning that I want to allow the receiver to decide when and how to batch ACKs together. Batching the ACKs would save time on the receiver side and may reduce the per message overhead it has.

I imagine how complicated it smells to achieve these goals. I hope I can prove it is not so complicated and in subsequent posts I want to experiment and may be partially implement the solution too.

### Introduction to the message flow

![Throttled reply](/images/experimentalprotocol_simple_nored.png)

This new messaging pattern introduces a new message type, the **Init** message and adds new fields to the **Ack** messages. Both are used to ensure reliability in a multi node environment.

### Init message

The Init message is responsible for setting up the communication channel. The sender talks to a single receiver who may talk to another receiver and so on. The role of the **Init** message is to tell the sender's preferences to receivers recursively.

I imagine a multi-node environment where each receiver-sender hop chooses a new hop based on the **Init** message it receives.

#### Message fields:

- **Channel ID**
- **Redundancy level** tells the receiver what is the expected redundancy the sender requires. In a usual setup all receivers would decrease the redundancy level, but that is not strictly necessary. When the last hop receives redundancy=1 then it may stop looking for new hops as long as the hop itself operates in such a way that it really helps redundancy.
- **Hop number** identifies how many hops the Init message went through
- **Exclude list** each hop is expected to add itself to this list to help the next hop finding a feasible host that does help redundancy. The exact rules of finding new hops is left to the hop. This is only a hint. Also, the hop is free to add other hosts too to this exclusion list if it sees fit.

The **Init** message has lots of potential. I don't want to explore all possibilities here (so I leave some for new posts), but let's include some:

- The exclude list format is not defined and the interpretation is left to the hop. Possibilities are endless. How about if the exclude list items tell the geo (or network) location of the node, so the next hop will prefer to choose the next hop in a different data center?
- We can add hops that doesn't change the redundancy level but still participate in the communication. An in memory cache for instance?

### Data message

The **Data** message is fairly simple.

#### Message fields:

- **Data ID**
- **Payload Size**
- **Payload**

I have not decided what the Data ID field should be. However I am very much in favor of Kafka style stream positions. That would have a number of benefits here as well.

### Ack message

The **Ack** messages can inform the sender about the number of receivers received the message and also the number of nodes who have processed the message. The receivers are allowed to send ACKs at every such event and they are also allowed to batch these events together.

#### Message fields:

- **ACKed ID** is the last message ID seen
- **Skipped** is the number of ACKs not sent since the last ACK message
- **#Delivered** tells how many times the message has been delivered to nodes
- **#Processed** tells how many nodes have processed the message

The next diagramm shows the case when both the delivery and the progress acknowledgements were batched together for three data messages: 

![Throttled reply](/images/experimentalprotocol_simple_combine.png)

In exchange for the performance gain we need to administer the outstanding ACKs on the sender side at each hop. The whole experiment is about the measurement of how these compare.

### Adding redundancy

So far I have only covered cases with a single receiver. The next example shows the case when the receivers acknowledge all messages at arrival and also when done. This shows how the number of ACKs explode which is a pure loss at first sight. Note also the different content of the **Init** messages while it is setting up the message distribution network.

![Throttled reply](/images/experimentalprotocol_simple_red2.png)

### Combining ACKs

To reduce the number of ACKs and thus save bandwidth and processing time, hops may choose to batch ACKs together. This is illustrated in the following diagram with redundancy=3 and two messages:

![Throttled reply](/images/experimentalprotocol_combine2_red3.png)

### Error handling and recovery

The error handling somewhat reflects to the Erlang / Elixir philosophy. Let it crash. If any party detect an anomaly it can and should close the connection. An obvious error scenario is when someone sends a **Data** message without a preceeding **Init**. 

![Throttled reply](/images/experimentalprotocol_missing_init.png)

I will need a bit more time to gather error scenarios and the best responses to them. 

The recovery part needs more thoughts too. My gut feeling is that I can delegate recovery to the parties and they should be able to recover based on the information they have, but I didn't have much time to think about this.

### Revisit design goals

The main goal of this messaging protocol is to enforce as little restrictions as possible but still provide a usable contract between parties. They should be able to decide what way they want to operate within these boundaries. I believe for example, that topology information shouldn't be encoded into the protocol even if multi-site redundancy is a must. That should be handled by the hops. The same way that I don't want the protocol to include timestamps which may be included in the payload.

### Future works

I want this post to be the go to place for this experimental protocol documentation so I will update this post when needed. I will use a [github repo](https://github.com/dbeck/tcp_ex_playground) for the code I develop while experimenting and may be refactor the results into a library if it worth the effort.

### Looking for feedback

All feedbacks and thoughts are very welcome. Please don't hesitate to share your thought through Disqus or feel free to ping me through Twitter (@dbeck74) or [Linkedin](https://hu.linkedin.com/in/davidbeckhungary).
