---
published: true
layout: post
category: Elixir
tags: 
  - elixir
  - performance
  - MacOSX
desc: Non-Scientific measurment of the cost of calling a remote process
description: Non-Scientific measurment of the cost of calling a remote process
author: David Beck
keywords: "Elixir, Performance, MacOSX"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/DSCF5286.JPG
woopra: callmeasurex
---

During my TCP experiment blog series I realized that sending messages to a remote Elixir process can slow down the sender process more than I expected. As José pointed out in his comment, passing messages involves copying the message from the sender. In addition to that, I had the gut feeling that it also has a hidden cost on top of the copying. This is a rough, non scientific attempt to estimate this hidden cost.

### Measurement code

To measure the cost on the sender side I created two versions of a tail recursive function. The ```local_fun``` does nothing just decreases a counter and continues its loop. The ```remote_fun``` also passes a **pid** parameter and sends the **val** to a remote process.

The ```measure_f``` function does multiple measurements bounded by time. In every step it tries to estimate how much time the next step will take. Steps are 1ms, 500ms, 3s and 10s.

The measurement itself only focuses on the mean value. Nothing else. No min, max, p95, etc... Again, it is for a rough estimate.

``` elixir
defmodule Testme do
  #
  # local_fun does a tail recursive call until val < 0.
  # 'local_fun' is the baseline for comparison to 'remote_fun'
  #
  
  def local_fun(val) when(val<=0) do
    :ok
  end
  
  def local_fun(val) when(val>0) do
    local_fun(val-1)
  end
  
  #
  # remote_loop is used to receive messages without doing
  # anything with them. it can be stopped too.
  #
  
  def remote_loop do
    receive do
      {:stop} -> :ok
      _ -> remote_loop
    end
  end
  
  #
  # remote_fun is almost the same as local_fun except that
  # it sends 'val' to the pid. the purpose of this function is
  # measuring how much it costs to send a message to another
  # local process.
  #
  
  def remote_fun(pid, val) when(val<=0) do
    send pid, {val}
    :ok
  end
  
  def remote_fun(pid, val) when(val>0) do
    send pid, {val}
    remote_fun(pid, val-1)
  end
  
  #
  # 'measure_f' tries to calculate the avarage speed of a function.
  # it tries to estimate the number of calls a function can be made in 10 seconds
  # in multiple steps, going up from 1ms, 500ms, 3s to 10s
  #
  
  def measure_f(name,f) do
    
    # check how much it takes to do 10 tail recursive loops of f.()
    {usec, :ok} = :timer.tc(fn -> f.(10) end,[])
    
    # estimate how many calls we can do in 1ms
    calls_1ms = 1000*10/(usec+1)
    
    # check the timing for our estimate
    {usec_1ms, :ok} = :timer.tc(fn -> f.(calls_1ms) end,[])

    # same thing as above for 500ms
    calls_500ms = calls_1ms*500_000/usec_1ms
    {usec_500ms, :ok} = :timer.tc(fn -> f.(calls_500ms) end,[])
    IO.puts "#{name} 500ms: calls/usec=#{calls_500ms/usec_500ms} usec/calls=#{usec_500ms/calls_500ms} calls_500ms=#{calls_500ms}"

    # based on the 500ms results, estimate the call count for 3s
    calls_3s = calls_500ms*3_000_000/usec_500ms
    {usec_3s, :ok} = :timer.tc(fn -> f.(calls_3s) end,[])
    IO.puts "#{name} 3s: calls/usec=#{calls_3s/usec_3s} usec/calls=#{usec_3s/calls_3s} calls_3s=#{calls_3s}"

    # based in the 3s results, estimate the call count for 10s
    calls_10s = calls_3s*10_000_000/usec_3s
    {usec_10s, :ok} = :timer.tc(fn -> f.(calls_10s) end,[])
    IO.puts "#{name} 10s: calls/usec=#{calls_10s/usec_10s} usec/calls=#{usec_10s/calls_10s} calls_10s=#{calls_10s}"
  end

  #
  # measure() does a local and remote function call measurement
  #
  
  def measure() do
    measure_f( "local", fn(a) -> Testme.local_fun(a) end )
    remote_pid = spawn_link(__MODULE__, :remote_loop, [])
    measure_f( "remote", fn(a) -> Testme.remote_fun(remote_pid, a) end )
    send remote_pid, {:stop}
  end
end

```

### Results

I ran this test on my Macbook Air, Mac OSX 10.10.5. 1,6 GHZ Intel Core i5.

```
iex(7)> Testme.measure
local 500ms: calls/usec=17.321217460430166 usec/calls=0.057732662399999995 calls_500ms=4230118.443316413
local 3s: calls/usec=18.155124699852 usec/calls=0.055080866506422396 calls_3s=51963652.381290495
local 10s: calls/usec=16.339053597624297 usec/calls=0.061203055245831396 calls_10s=181551246.99852
remote 500ms: calls/usec=2.5474734101654577 usec/calls=0.3925458048 calls_500ms=1584283.9036755387
remote 3s: calls/usec=2.20241832825882 usec/calls=0.45404634858382076 calls_3s=7642420.230496373
remote 10s: calls/usec=2.550138364764963 usec/calls=0.39213558519683156 calls_10s=22024183.282588203
{:stop}
```

I don't want to make too many conclusions out of this experiment. The ```remote_fun``` passes a bit more data because of the extra **pid** parameter. With that I say on my system calling ```remote_fun``` takes roughly seven times more time than ```local_fun```.

Also, calling ```remote_fun``` takes roughly **0.33** microsecond more than ```local_fun``` which on my system is around **4848** clock cycles. Even if copying the extra parameter, this is a considerable amount of time for some uses cases, for others it doesn't matter.

