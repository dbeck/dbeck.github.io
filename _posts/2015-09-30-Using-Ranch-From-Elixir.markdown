---
published: true
layout: post
category: Elixir
tags:
  - elixir
  - ranch
  - TCP
desc: Using Ranch From Elixir
description: Using Ranch From Elixir
keywords: "Elixir, Ranch, Erlang, TCP"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/P9083758.JPG
pageid: usingranchex
---

This post goes reverse order. Results and conclusion first. Background and motivation last. I keep my random ramblings to the end so you can save yourself earlier.

### TestMe2 - the result

This is the result of my experiment. A TCP echo server in Elixir that uses the Erlang [ranch library](https://github.com/ninenines/ranch).

I used ```mix new testme2 --sup --module TestMe2``` to generate the project.

Then I added ranch into the dependencies and to the OTP applications. The resulting ```mix.exs``` looks like this:

``` elixir
defmodule TestMe2.Mixfile do
  use Mix.Project

  def project do
    [app: :testme2,
     version: "0.0.1",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :ranch],
     mod: {TestMe2, []}]
  end

  defp deps do
    [
     {:ranch, "~> 1.1"}
    ]
  end
end

```

Then I integrated my application into OTP in ```lib/testme2.ex```:

``` elixir
defmodule TestMe2 do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(TestMe2.Worker, [])
    ]

    opts = [strategy: :one_for_one, name: TestMe2.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Added a Worker like this in ```lib/testme2_worker.ex```:

``` elixir
defmodule TestMe2.Worker do
  def start_link do
    opts = [port: 8000]
    {:ok, _} = :ranch.start_listener(:Testme2, 100, :ranch_tcp, opts, TestMe2.Handler, [])
  end
end
```

Finally I needed a handler to actually talk TCP in ```lib/testme2_handler.ex```:

``` elixir
defmodule TestMe2.Handler do

  def start_link(ref, socket, transport, opts) do
    pid = spawn_link(__MODULE__, :init, [ref, socket, transport, opts])
    {:ok, pid}
  end

  def init(ref, socket, transport, _Opts = []) do
    :ok = :ranch.accept_ack(ref)
    loop(socket, transport)
  end

  def loop(socket, transport) do
    case transport.recv(socket, 0, 5000) do
      {:ok, data} ->
        transport.send(socket, data)
        loop(socket, transport)
      _ ->
        :ok = transport.close(socket)
    end
  end
end
```

That's about it. If you do the same you should have a fast TCP echo server.

### The conclusion

The conclusion is simple: if you are new to both Elixir and Erlang, it is not a good idea to start by integrating an Erlang lib into Elixir. I made a very silly mistake and the result compiled without a warning. It was running without any warnings. It was listening to the port I specified. Only that my telnet connection was closed immediately after it had beed connected. No debug log, nothing.

Even though I like Elixir a lot and respect Erlang VM a whole other lot, it was very annoying. Making no mistakes, let me emphasize again: I made the mistake. It was just bad that it didn't bark even a bit at me.

### Testme1 - the bad code

``` elixir
defmodule Testme1.Handler do

  def start_link(Ref, Socket, Transport, Opts) do
    Pid = spawn_link(__MODULE__, :init, [Ref, Socket, Transport, Opts])
    {:ok, Pid}
  end

  def init(Ref, Socket, Transport, _Opts = []) do
    :ok = :ranch.accept_ack(Ref)
    loop(Socket, Transport)
  end

  def loop(Socket, Transport) do
    case :Transport.recv(Socket, 0, 5000) do
      {:ok, Data} ->
        :Transport.send(Socket, Data)
        loop(Socket, Transport)
      _ ->
        :ok = :Transport.close(Socket)
    end
  end
end

```

I guess any seasoned Elixir folk would immediately recognize the problem. If you don't then compare this to the handler above in ```lib/testme2_handler.ex```. The difference is subtle. The function parameters are capitalized. No one would do such a mistake, except me when I copied and adapted the ranch Erlang TCP echo example from [here](https://github.com/ninenines/ranch/blob/master/examples/tcp_echo/src/echo_protocol.erl).

I fixed all the Erlang and Elixir syntax differences but somehow overlooked these capitalized names.

### Motivation

The reason I am looking at Elixir is to do a distributed service with TCP. I did a lot of BSD socket programming in C++ so I know the options there. I started my research to see what people say about fast TCP servers in Elixir and Erlang. Cowboy and Ranch came out quite fast and I also found mentions about the default OTP TCP might not be fast enough to accept large number of connections.

Then I spent quite some time looking for an Elixir alternative to Ranch. What I found was either [gen_tcp based](https://github.com/meh/reagent) or advertised that it is [not for production](https://github.com/slogsdon/pool).

### Background

I have no Erlang or Elixir experience. I have read Dave Thomas' Programming in Elixir. I have looked at Erlang for long and always wanted to use the BEAM Virtual Machine for a real project.

One great plus on the Elixir side is the possibility to use Erlang libraries. I read that this should be easy. For further preparation I also read the Little Elixir and & OTP Guidebook from Benjamin Tan Wei Hao. I always liked the OTP concepts and expected that most Erlang and Elixir libs will use it.
