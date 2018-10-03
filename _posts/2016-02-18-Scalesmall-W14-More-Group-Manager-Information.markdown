---
published: true
layout: post
category: "ScaleSmall for Elixir"
tags:
  - elixir
  - scalesmall
  - group-manager
  - gossip
desc: ScaleSmall Experiment Week Fourteen / More Group Manager information
description: ScaleSmall Experiment Week Fourteen / More Group Manager information
keywords: "Elixir, Distributed, Erlang, Scalable, Group, Manager"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF6936.JPG
pageid: scalesmallw14
scalesmall_subscribe: false
---

I received very interesting and valuable responses about [the previous post](/Scalesmall-W11-W13-Group-Manager-Implementation/), so thanks again to [José Valim](https://twitter.com/josevalim) and [Deprecated BIF](https://twitter.com/dch__) for the inputs and spending time to read my ramblings.

It became clear how much non-revolutionary the [GroupManager](https://github.com/dbeck/scalesmall/tree/w15/apps/group_manager) is and similar things already existed, both in terms of group management and group communication. In this post I try to summarize the similarities and differences to some of the existing approaches.

I have made progress also with the group management code during the past week so the second part of this post will focus on the changes.

![slippers](/images/DSCF6936.JPG)

### What is a group

It was a real eye opener to see how many ways people attacked this problem. Examples:

- [Natalia Chechina - Scalable Distributed Erlang on Youtube](https://www.youtube.com/watch?v=dWpsesw_UQU) (link thanks to [Deprecated BIF](https://twitter.com/dch__))
- [SWIM: Scalable Weakly-consistent Infection-style Process Group Membership
Protocol](https://www.cs.cornell.edu/~asdas/research/dsn02-swim.pdf) (link thanks to [José Valim](https://twitter.com/josevalim))

Group management in this context is about managing group membership information of a set of nodes or processes. Even if this description is simple the design space for an actual implementation is a lot larger. Questions:

- remove dead members? allow dead members?
- clear cut between application and library or VM code?
- allow being a member of multiple groups?
- group member distance

### Remove dead members? Allow dead members?

The authors of the [SWIM](https://www.cs.cornell.edu/~asdas/research/dsn02-swim.pdf) paper pointed out very well that there are two separate concerns in group management:

- detecting nodes down and
- managing the group membership information

I fully agree with this view. In SWIM this idea is used for piggybacking the membership information on top of the node failure detection.

I take this view even further, for practical and theoretical reasons too. The theoretical one is that I think it is valuable to maintain group membership information without monitoring the members or removing them when they are down. I treat the group topology as a shared database, nothing more. The other, more practical reason is that I don't see any benefit of developing monitoring code since the BEAM VM is already able to monitor nodes. If for any reason it doesn't fit my needs I may develop a solution or look for an existing one.

The other interesting aspect of this topic is why do I need to remove dead members from the group? It is pretty much of a design question. Some systems may need this functionality bundled with group management, others may not. I beleive by not bundling these together `scalesmall` group manager is more flexible.

### Clear cut between application and library or VM code?

If we think about the software stack as layers of `Runtime` + `Library` + `Application`, it is an interesting decision of which part should be responsible for the group management.

In [SD Erlang](https://www.youtube.com/watch?v=dWpsesw_UQU) they seem to favor a low level integration into the BEAM VM. I think this is a reasonable choice, especially because the existing node monitiring code already lives there.

I have a few reasons why I want `scalesmall` group manager to be different:

- I want the group management protocol to be compatible with other languages and a less tight integration with the BEAM VM makes this easier. So I may be able to group Elixir and non-Elixir nodes together. (Rust and Clojure are first two on my list.)
- I want `scalesmall` to progress even if my group management code doesn't get integrated into the mainstream Erlang code.
- I want a non-traditional cut between `Library` and `Application` code. More on that below in the `Exercise` part.

#### Exercise

Let's define a use-case for the group manager: I have a huge customer database that I want to shard over a set of machines. For a start I don't think about redundancy. Let's suppose I have three machines: M1, M2 and M3. How would a group manager help in this?

**Let's define 3 groups**:

- `"Customers A-H"` : members: [M1]
- `"Customers I-Q"` : members: [M2]
- `"Customers R-Z"` : members: [M3]

**Now add redundancy=2**:

- `"Customers A-H"` : members: [M1, M2]
- `"Customers I-Q"` : members: [M2, M3]
- `"Customers R-Z"` : members: [M3, M1]

This solution has a few problems and advantages. When a range outgrows the capacity of a single machine, I will need to split the range and assign more machines to it. To make this simple I should better use similar machines, which is another drawback. The advantage is that groups define who needs to talk to whom naturally. No unneed chatter takes place.

In `scalesmall` I would use a single group to solve this problem, because `scalesmall` membership information also contains a `start_range` and `end_range` which I could use as subgroups. From the layered design perspective this is a dirty hack. A clean separation of `Application`  vs `Library` code would require the library not knowing about things like ranges. I chose this model because the simple set-like abtraction of group membership is not rich enough to my opinion.

**Scalesmall way**:

So the above exercise in `scalesmall` would require a single `"Customers"` group with these members:

- `(M1, A-H)`
- `(M2, A-H)`
- `(M2, I-Q)`
- `(M3, I-Q)`
- `(M3, R-Z)`
- `(M1, R-Z)`

Once I have a single group I potentially lose a nice property of the '3 groups' approach above: the 3 groups are independent, so only the nodes who has actual work to do for a given shard need to communicate. If I have a single group then `M3` may hear messages about the `A-H` range, even if it has nothing to do with it. This will be handled in `scalesmall` (in the future).

### Allow being a member of multiple groups?

Scalesmall allows being a member of multiple groups which provides lots of flexibility when designing an architecture. One might assign groups based on the physical location, role, capacity or other factors.

### Group member distance

A very interesting idea in [SD Erlang](https://www.youtube.com/watch?v=dWpsesw_UQU) is the way it defines distance between nodes. In `scalesmall` we have only two distance values.

- near nodes: those we can access on UDP multicast
- far nodes: everyone else

This is a simplistic model and I am tempted to design something more sophisticated in the future. The advantage with the current approach is that it learns about the network topology automatically and no additional information is needed.

### Quick recap of scalesmall group management

- `scalesmall` doesn't check nodes health, neither does it remove dead nodes
- scalesmall group membership information contains 3 additional information:
    + `start range` and `end range`
    + `port`
- uses a gossip based communication, UDP multicast on the Local LAN and a logarithmic broadcast on top of TCP (more on this [here](/Scalesmall-W11-W13-Group-Manager-Implementation/) and [here](/Scalesmall-W5-UDP-Multicast-Mixed-With-TCP/))

### Progress since last week

I reduced the technical debt around the group-manager code:

- the messages became a lot smaller, because I added a manual serialization instead of the `:erlang.term_to_binary` (NB messages were compressed already in the previous release by snappy). This new serialization drops message sizes to 1/10th.
- the messages are now encrypted and they have checksum too

To support message encryption one needs to define a key in the group manager configuration as `group_manager.key`:

```elixir
use Mix.Config

config :group_manager,
  my_addr: System.get_env("GROUP_MANAGER_ADDRESS"),
  my_port: System.get_env("GROUP_MANAGER_PORT") || "29999",
  multicast_addr: System.get_env("GROUP_MANAGER_MULTICAST_ADDRESS") || "224.1.1.1",
  multicast_port: System.get_env("GROUP_MANAGER_MULTICAST_PORT") || "29999",
  multicast_ttl: System.get_env("GROUP_MANAGER_MULTICAST_TTL") || "4",
  key: System.get_env("GROUP_MANAGER_KEY") || "01234567890123456789012345678912"
```

This new release became `0.0.5`:

```elixir
{:scalesmall, git: "https://github.com/dbeck/scalesmall.git", tag: "0.0.5"}
```

### Future plans

I think `scalesmall` is now ready for focusing on a real task. I am constantly hesitating between these possible next steps:

- make a showcase for a larger user base, like create a sharded database and integrate it into Phoenix
- focus on the initial goal and create the small message server, and see who would be interested
- make another learning experiment with Elm and add a UI for the GroupManager
- pick a new language to experiment with and implement the same GroupManager there too (and make them compatible on the message level). my first choices would be Rust and Clojure

I have a bit of a debt on the testing front too, which I want to clear before jumping into one of the above. If you have any suggestions or inputs, please don't hesitate to ping me on [twitter](https://twitter.com/dbeck74) or Disqus (below) or privately at david(dot)beck(dot)priv(at)gmail(dot)com.

### Episodes

1. [Ideas to experiment with](/Scalesmall-Experiment-Begins/)
2. [More ideas and a first protocol that is not in use anymore](/Scalesmall-W1-Combininig-Events/)
3. [Got rid of the original protocol and looking into CRDTs](/Scalesmall-W2-First-Redesign/)
4. [My first ramblings about function guards](/Scalesmall-W3-Elixir-Macro-Guards/)
5. [The group membership messages](/Scalesmall-W4-Message-Contents-Finalized/)
6. [Design of a mixed broadcast](/Scalesmall-W5-UDP-Multicast-Mixed-With-TCP/)
7. [My ARM based testbed](/Scalesmall-W6-W7-Test-environment/)
8. [Experience with defstruct, defrecord and ETS](/Scalesmall-W8-W10-Elixir-Tuples-Maps-and-ETS/)
9. [GroupManager code works, beta](/Scalesmall-W11-W13-Group-Manager-Implementation/)
10. [GroupManager more information and improvements](/Scalesmall-W14-More-Group-Manager-Information/)
