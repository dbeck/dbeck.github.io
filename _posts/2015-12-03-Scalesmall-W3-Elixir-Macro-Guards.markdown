---
published: true
layout: post
category: Elixir
tags:
  - elixir
  - distributed
  - scalesmall
  - macro
desc: ScaleSmall Experiment Week Three / Started Implementing the CRDTs
description: ScaleSmall Experiment Week Three / Started Implementing the CRDTs
keywords: "Elixir, Distributed, Erlang, Macro, High-performance, Scalable, CRDT"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF6125.JPG
woopra: scalesmallw3
scalesmall_subscribe: false
---

I guess I am still carrying a lot of my C++ baggage and not fully grasped the idiomatic Elixir thing. Hope you will correct me and suggest better options. While implementing the CRDT for my group messages I had the feeling that I am still doing what I practiced for OO for long:

- I model the problem space based on objects
- These objects became Elixir modules
- Each of these Elixir module has a ```Record```
- Then I added accessor and manipulator functions
- I also added a validator macro to be used in guards

Let's go through these.

![weirdos](/images/DSCF6125.JPG)

### Using the Record module

```Elixir
defmodule GroupManager.Data.Item do
  require Record
  Record.defrecord :item, member: nil, start_range: 0, end_range: 0xffffffff, priority: 0
  @type t :: record( :item, member: term, start_range: integer, end_range: integer, priority: integer )
end
```

Let's try using this new object:

```
iex(2)> GroupManager.Data.Item.item
** (CompileError) iex:2: you must require GroupManager.Data.Item before invoking the macro GroupManager.Data.Item.item/0
    (elixir) src/elixir_dispatch.erl:98: :elixir_dispatch.dispatch_require/6
iex(2)> require GroupManager.Data.Item
nil
iex(3)> GroupManager.Data.Item.item
{:item, nil, 0, 4294967295, 0}
```

I don't want to force the users of this *Object* to ```require GroupManager.Data.Item``` because I want the binding of my record structure and the Item module more transparent. For that reason I add a ```new()``` function. I want to enforce the user to fill the member in my record:

```Elixir
defmodule GroupManager.Data.Item do

  require Record
  Record.defrecord :item, member: nil, start_range: 0, end_range: 0xffffffff, priority: 0
  @type t :: record( :item, member: term, start_range: integer, end_range: integer, priority: integer )

  @spec new(term) :: t
  def new(id)
  do
    item(member: id)
  end
end
```

Let's try this:

```
iex(2)> GroupManager.Data.Item.new
** (UndefinedFunctionError) undefined function: GroupManager.Data.Item.new/0
    GroupManager.Data.Item.new()
iex(2)> GroupManager.Data.Item.new(node())
{:item, :nonode@nohost, 0, 4294967295, 0}
```

### Enforcing invariants

I want my module to be as defensive as possible, so whenever I receive a ```GroupManager.Data.Item.t``` parameter I want to check both its structure and its members. Things to check are:

- received the proper data type
- has all the required members
- the range, and priority parameters are 32bit unsigned integers
- the member *variable* is not nil
- start_ range is <= end_range

I can check these invariants like this:

```Elixir
def myfunc({:item, member, start_range, end_range, priority})
when
  is_nil(member) == false and
  start_range >= 0 and
  start_range <= 0xffffffffff and
  end_range >= 0 and
  end_range <= 0xffffffffff and
  priority <= 0 and
  priority >= 0xffffffffff and
  start_range <= end_range
do
  :ok
end
```

I want to validate the input everywhere so my mistakes can come out early. When I first written this huge ```when clause``` I knew I need something better. Especially because I want this logic to be exportable easily, so when an another module receives an Item object, it should be able to check if it is a valid one. Copying this ```when``` block everywhere is both error prone and tedious.

### Guard macro

The best would be to create something like this:

```Elixir
def myfunc(obj)
when is_valid(obj)
do
  :ok
end
```

Now the question is how to implement this ```is_valid``` guard. It turned out this cannot be a simple function. It has to be a macro. I checked the Elixir sources and found how [Record.is_record was implemented](https://github.com/elixir-lang/elixir/blob/master/lib/elixir/lib/record.ex#L84). With a bit of tweaking I came up with this thing:

```Elixir
  defmacro is_valid(data) do
    case Macro.Env.in_guard?(__CALLER__) do
      true ->
        quote do
          is_tuple(unquote(data)) and tuple_size(unquote(data)) == 5 and
          :erlang.element(1, unquote(data)) == :item and
          # member
          is_nil(:erlang.element(2, unquote(data))) == false and
          # start_range
          is_integer(:erlang.element(3, unquote(data))) and
          :erlang.element(3, unquote(data)) >= 0 and
          :erlang.element(3, unquote(data)) <= 0xffffffff and
          # end_range
          is_integer(:erlang.element(4, unquote(data))) and
          :erlang.element(4, unquote(data)) >= 0 and
          :erlang.element(4, unquote(data)) <= 0xffffffff and
          # priority
          is_integer(:erlang.element(5, unquote(data))) and
          :erlang.element(5, unquote(data)) >= 0 and
          :erlang.element(5, unquote(data)) <= 0xffffffff and
          # start_range <= end_range
          :erlang.element(3, unquote(data)) <= :erlang.element(4, unquote(data))
        end
      false ->
        quote do
          result = unquote(data)
          is_tuple(result) and tuple_size(result) == 5 and
          :erlang.element(1, result) == :item and
          # member
          is_nil(:erlang.element(2, result)) == false and
          # start_range
          is_integer(:erlang.element(3, result)) and
          :erlang.element(3,result) >= 0 and
          :erlang.element(3, result) <= 0xffffffff and
          # end_range
          is_integer(:erlang.element(4, result)) and
          :erlang.element(4, result) >= 0 and
          :erlang.element(4, result) <= 0xffffffff and
          # priority
          is_integer(:erlang.element(5, result)) and
          :erlang.element(5, result) >= 0 and
          :erlang.element(5, result) <= 0xffffffff and
          # start_range <= end_range
          :erlang.element(3, result) <= :erlang.element(4,result)
        end
    end
  end
```

This is ugly, but has to be implemented once. Let's try it:

```
iex(2)> c = GroupManager.Data.Item.new(node())
{:item, :nonode@nohost, 0, 4294967295, 0}
iex(3)> GroupManager.Data.Item.is_valid(c)
** (CompileError) iex:3: you must require GroupManager.Data.Item before invoking the macro GroupManager.Data.Item.is_valid/1
    (elixir) src/elixir_dispatch.erl:98: :elixir_dispatch.dispatch_require/6
iex(3)> require GroupManager.Data.Item
nil
iex(4)> GroupManager.Data.Item.is_valid(c)
true
```

Same as before. I need to ```require GroupManager.Data.Item``` in order to use it. Let's add a few helpers to make life easier:

```Elixir
  @spec valid?(t) :: boolean
  def valid?(data)
  when is_valid(data)
  do
    true
  end

  def valid?(_), do: false
```

This is now more convenient:

```
iex(2)> c = GroupManager.Data.Item.new(node())
{:item, :nonode@nohost, 0, 4294967295, 0}
iex(3)> GroupManager.Data.Item.valid?(c)
true
iex(4)> GroupManager.Data.Item.valid?(:ok)
false
```

### Other progress

This week I completed the design of the messages between group members based on CRDT types. I decided to model the mapping between the ```group member``` and the ```(start_ range, end_range, priority)``` triple with a similar structure to the [Last Write Wins Set](https://github.com/aphyr/meangirls#lww-element-set) that is in use in [SoundCloud's Roshi](https://developers.soundcloud.com/blog/roshi-a-crdt-system-for-timestamped-events) with a bias on removes.

In the next episode I will give more details about their implementation. If you would like to look into the code, here it is:

- [GroupManager.Data.Item](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/lib/group_manager/data/item.ex) / [GroupManager.Data.ItemTest](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/test/group_manager/data/item_test.exs)
- [GroupManager.Data.LocalClock](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/lib/group_manager/data/local_clock.ex) / [GroupManager.Data.LocalClockTest](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/test/group_manager/data/local_clock_test.exs)
- [GroupManager.Data.Message](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/lib/group_manager/data/message.ex) / [GroupManager.Data.MessageTest](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/test/group_manager/data/message_test.exs)
- [GroupManager.Data.MessageLog](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/lib/group_manager/data/message_log.ex) / [GroupManager.Data.MessageLogTest](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/test/group_manager/data/message_log_test.exs)
- [GroupManager.Data.TimedItem](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/lib/group_manager/data/timed_item.ex) / [GroupManager.Data.TimedItemTest](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/test/group_manager/data/timed_item_test.exs)
- [GroupManager.Data.TimedSet](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/lib/group_manager/data/timed_set.ex) / [GroupManager.Data.TimedSetTest](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/test/group_manager/data/timed_set_test.exs)
- [GroupManager.Data.WorldClock](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/lib/group_manager/data/world_clock.ex) / [GroupManager.Data.WorldClockTest](https://github.com/dbeck/scalesmall/blob/master/apps/group_manager/test/group_manager/data/world_clock_test.exs)


If you look at the code you will find instances where I check other invariants like ```is_empty()``` with similar macros. I just feel like more secure if my functions are not even implemented for invalid inputs.

### Episodes

1. [Ideas to experiment with](/Scalesmall-Experiment-Begins/)
2. [More ideas and a first protocol that is not in use anymore](/Scalesmall-W1-Combininig-Events/)
3. [Got rid of the original protocol and looking into CRDTs](/Scalesmall-W2-First-Redesign/)
4. [My first ramblings about function guards](/Scalesmall-W3-Elixir-Macro-Guards/)
5. [The group membership messages](/Scalesmall-W4-Message-Contents-Finalized/)
6. [Design of a mixed broadcast](/Scalesmall-W5-UDP-Multicast-Mixed-With-TCP/)
7. [My ARM based testbed](/Scalesmall-W6-W7-Test-environment/)
8. [Experience with defstruct, defrecord and ETS](/Scalesmall-W8-W10-Elixir-Tuples-Maps-and-ETS/)

### Need help

If you have any suggestions on how to improve my code, style, anything... or disagree with my views, please don't hesitate to comment and share your view. I want to improve. Thanks a lot in advance.
