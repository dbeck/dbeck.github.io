---
published: true
layout: post
category: Elixir
tags:
  - elixir
  - scalesmall
  - ETS
desc: ScaleSmall Experiment Week Eigth to Ten / OOP, ETS and Status
description: ScaleSmall Experiment Week Eigth to Ten / OOP, ETS and Status
keywords: "Elixir, Distributed, Erlang, Scalable, ETS, OOP"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF5297.JPG
woopra: scalesmallw9
scalesmall_subscribe: true
---

Scalesmall in the past weeks progressed very well so I even forgot to post about it. Should I do the same again, please have a look at the [github repo](https://github.com/dbeck/scalesmall) to have a rough idea what goes on.

In this post I will start with a few observations about ETS and my transition from the OOP world to Elixir. Finally I will write a bit about the status of scalesmall.

While I am playing with `scalesmall` I also spend time to find a job. Right now I am happily unemployed, writing CVs, doing IKM and interviews. Interesting days.

![OOP](/images/DSCF5297.JPG)

### OOP

For me to start writing programs with functions only, using immutable variables was easy. I even enjoy it. When C++11 came out I found myself writing more and more lambda functions for rapid prototyping and trying out ideas without all the ceremony of classes.

Now that I am using Elixir for some momths now, I found myself missing my dirty little classes again. Especially these things:

- when I need complex data structures to represent certain objects
- I feel better when I am sure that theses data structures meet certain conditions

With C++ classes I could easily control how member variables change. I could enforce predicates and relations of member variables. It took some time to find the Elixir ways for this.

#### Complex structures

For any non-trivial program I need data types that contain multiple members that serves the same purpose. I found two options for my purposes:

- [struct](http://elixir-lang.org/getting-started/structs.html)
- [record](http://elixir-lang.org/docs/v1.1/elixir/Record.html)

To protect myself from my ignorance while learning a new language, I feel safer, if I can make sure that the members of my data type are well defined. Plus I want to make sure that the content of the member variables meet certain conditions.

To demonstrate the idea let's imagine a `MyDate` object that:

- has a `month` and a `date` field
- all of them are positive integers
- the `month` is <= 12
- the Date is <= 31, but in February it is <= 29

Let's ignore leap years and all the different day counts in the various months. The point of this example is not to develop a correct `MyDate` object, but to show a few ideas about member validation.

I would like to use an Elixir module to hold all `MyDate` related functions at one place.

#### First attempt using maps (structs)

```Elixir
defmodule MyDate do
  defstruct month: 1, day: 1

  def new(), do: %MyDate{}

  def set_month(date = %MyDate{month: _m, day: day}, month)
  when is_integer(day) and day > 0 and
       is_integer(month) and month > 0 and month <= 12 and
       ((month == 2 and day <= 29) or (month != 2 and day <= 31))
  do
    %{date | month: month}
  end

  def set_day(date = %MyDate{month: month, day: _day}, day)
  when is_integer(day) and day > 0 and
       is_integer(month) and month > 0 and month <= 12 and
       ((month == 2 and day <= 29) or (month != 2 and day <= 31))
  do
    %{date | day: day}
  end

  def get_month(%MyDate{month: month, day: day})
  when is_integer(day) and day > 0 and
       is_integer(month) and month > 0 and month <= 12 and
       ((month == 2 and day <= 29) or (month != 2 and day <= 31))
  do
    month
  end

  def get_day(%MyDate{month: month, day: day})
  when is_integer(day) and day > 0 and
       is_integer(month) and month > 0 and month <= 12 and
       ((month == 2 and day <= 29) or (month != 2 and day <= 31))
  do
    day
  end
end
```

What I wanted to achieve is to validate the `MyDate` object whenever I want to work with it. The validation code is copied to all places which is not nice.

#### Second attempt: improve validation

```Elixir
defmodule MyDate do
  defstruct month: 1, day: 1

  def new(), do: %MyDate{}

  defmacro is_valid(month, day)
  do
    quote do
      is_integer(unquote(day)) and unquote(day) > 0 and
      is_integer(unquote(month)) and unquote(month) > 0 and unquote(month) <= 12 and
      ((unquote(month) == 2 and unquote(day) <= 29) or (unquote(month) != 2 and unquote(day) <= 31))
    end
  end

  def set_month(date = %MyDate{month: _m, day: day}, month)
  when is_valid(month, day)
  do
    %{date | month: month}
  end

  def set_day(date = %MyDate{month: month, day: _day}, day)
  when is_valid(month, day)
  do
    %{date | day: day}
  end

  def get_month(%MyDate{month: month, day: day})
  when is_valid(month, day)
  do
    month
  end

  def get_day(%MyDate{month: month, day: day})
  when is_valid(month, day)
  do
    day
  end
end
```

Now the validation code has moved to the `is_valid` macro. This is nicer and also allows other modules to validate the `MyDate` object. Let's imagine I have a `MyDateTime` object like this:

```Elixir
defmodule MyDateTime do

  require MyDate

  defstruct date: %MyDate{}, hour: 0

  def new, do: %MyDateTime{}

  defmacro is_valid(hour)
  do
    quote do
      is_integer(unquote(hour)) and unquote(hour) >= 0 and unquote(hour) < 24
    end
  end

  def set_hour(date_time = %MyDateTime{date: %MyDate{month: month, day: day}}, hour)
  when MyDate.is_valid(month, day) and
       is_valid(hour)
  do
    %{date_time | hour: hour}
  end

  def set_date(date_time = %MyDateTime{hour: hour}, date = %MyDate{month: month, day: day})
  when MyDate.is_valid(month, day) and
      is_valid(hour)
  do
    %{date_time | date: date}
  end
end
```

I omitted minute and second because hour illustrates my point. With a bit of pattern matching I could reuse the validation code from the `MyDate` module. This bit of pattern matching is a pain. It introduces coupling between the structure of the module and its users. Furthermore, more levels of nesting makes the code unreadable. Also, if I rename a member or add new members, such as a `year` to MyDate, then I need to update:

- the `is_valid` macro in `MyDate`
- all patterns where I extracted the fields
- and all macro invocations

This is clearly no way to go. There would be an easy solution to this if I could validate `MyDate` by passing only one `MyDate` parameter rather then the extracted fields. Unfortunately I cannot do that due to the limitations of function guards. At least I could not come up with a solution so far.

#### Third attempt: us defrecord

By using tuples instead of Maps I can improve this landscape a lot. Let's see how:

```Elixir
defmodule MyDate do

  require Record
  Record.defrecord :my_date, month: 1, day: 1

  def new(), do: my_date()

  defmacro is_valid_month_day(month, day)
  do
    quote do
      # month
      is_integer(unquote(month)) and
      unquote(month) > 0 and
      unquote(month) <= 12 and
      # day
      is_integer(unquote(day)) and
      unquote(day) > 0 and
      # month and day
      ( (unquote(month) == 2 and unquote(day) <= 29) or
        (unquote(month) != 2 and unquote(day) <= 31) )
    end
  end

  defmacro is_valid(obj)
  do
    quote do
      # object's structure
      is_tuple(unquote(obj)) and
      tuple_size(unquote(obj)) == 3 and
      :erlang.element(1, unquote(obj)) == :my_date and
      # month
      is_integer(:erlang.element(2, unquote(obj))) and
      :erlang.element(2, unquote(obj)) > 0 and
      :erlang.element(2, unquote(obj)) <= 12 and
      # day
      is_integer(:erlang.element(3, unquote(obj))) and
      :erlang.element(3, unquote(obj)) > 0 and
      # month and day
      ( (:erlang.element(2, unquote(obj)) == 2 and :erlang.element(3, unquote(obj)) <= 29) or
        (:erlang.element(2, unquote(obj)) != 2 and :erlang.element(3, unquote(obj)) <= 31) )
    end
  end

  def set_month(date = {:my_date, _month, day}, month)
  when is_valid_month_day(month, day)
  do
    my_date(date, month: month)
  end

  def set_day(date = {:my_date, month, _day}, day)
  when is_valid_month_day(month, day)
  do
    my_date(date, day: day)
  end

  def get_month(date)
  when is_valid(date)
  do
    my_date(date, :month)
  end

  def get_day(date)
  when is_valid(date)
  do
    my_date(date, :day)
  end
end
```

Now I can validate a `MyDate` object with a single `MyDate.is_valid` macro call and as you will see it doesn't leak the internal structure into users of the `MyDate` module:

```Elixir
defmodule MyDateTime do

  require MyDate
  require Record
  Record.defrecord :my_date_time, date: MyDate.new, hour: 0

  def new, do: my_date_time()

  defmacro is_valid_hour(hour)
  do
    quote do
      is_integer(unquote(hour)) and
      unquote(hour) >= 0 and
      unquote(hour) < 24
    end
  end

  defmacro is_valid(obj)
  do
    quote do
      # object's structure
      is_tuple(unquote(obj)) and
      tuple_size(unquote(obj)) == 3 and
      :erlang.element(1, unquote(obj)) == :my_date_time and
      # data
      MyDate.is_valid(:erlang.element(2, unquote(obj))) and
      is_valid_hour(:erlang.element(3, unquote(obj)))
    end
  end

  def set_hour(date_time, hour)
  when is_valid(date_time) and
       is_valid_hour(hour)
  do
    my_date_time(date_time, hour: hour)
  end

  def set_date(date_time, date)
  when is_valid(date_time) and
       MyDate.is_valid(date)
  do
    my_date_time(date_time, date: date)
  end
end

```

`MyDateTime` don't need to pattern match the internal structure of the `MyDate` object in order to validate it. My conclusion so far about this is that I will stick to using `defrecord` instead of `defstruct` because the program structure will be more sound and this doesn't introduce unintended coupling between modules. (At least with my extra-paranoid defensive programming style.)

#### Conclusion

The major difference between tuples and maps is that the former can be validated in guard expressions. This includes the data structure and also the member values. The roots of this difference are coming from the range of [allowed expressions for guards](http://erlang.org/doc/reference_manual/expressions.html#id83710) in the BEAM VM. If you look closer you will notice that there is no support for extracting members of a map within a guard expression. For tuples there is `:erlang.element`.

### ETS

Very different topic. There are lots of tutorials about ETS like [this in Elixir](http://learningelixir.joekain.com/building-a-cache-in-elixir-with-ets/) and [this one in Erlang](http://learnyousomeerlang.com/ets) and I also suggest to read the official [Elixir ETS](http://elixir-lang.org/getting-started/mix-otp/ets.html) and [Erlang ETS](http://www.erlang.org/doc/man/ets.html) docs about it.

I won't start from the ETS introduction here.

#### ETS and tuples




### Scalesmall status

### Episodes
