---
published: true
layout: post
category: Elixir
tags: 
  - elixir
  - ranch
  - TCP
  - erlang
desc: Using Ranch From Elixir
keywords: "Elixir, Ranch, Erlang, TCP"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/P9083758.JPG
woopra: usingranchex
---

This post goes reverse order. Results and conclusion first. Background and motivation last. I keep my random ramblings to the end so you can save yourself earlier.

### TestMe2 

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
    {:ok, pid} = :ranch.start_listener(:Testme2, 100, :ranch_tcp, opts, TestMe2.Handler, [])
    {:ok, pid}
  end
end
```

Finally we need a handler to actually talk TCP in ```lib/testme2_handler.ex```:

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



This post is about my first steps in Elixir land. I have no Erlang or Elixir experience, though I have read Dave Thomas' Programming in Elixir. I have looked at Erlang for long and always wanted to use the BEAM Virtual Machine for a real project. 

One great plus on the Elixir side is the possibility to use Erlang libraries. I read that this should be easy. For further preparation I also read the Little Elixir and & OTP Guidebook from Benjamin Tan Wei Hao. I always liked the OTP concepts and expected that most Erlang and Elixir libs will use it.

### TCP Server

The reason I am looking at Elixir is to do a distributed service with TCP. I did a lot of BSD socket programming in C++ so I know the options there. I started my research to see what people say about fast TCP servers in Elixir and Erlang. Cowboy and Ranch came out quite fast and I also found mentions about the default OTP TCP might not be fast enough.  

Then I spent quite some time looking for an Elixir alternative to Ranch. What I found was either gen_tcp based or advertised that it is not for production.

Again these are my naive attempts, I was just looking for a reasonable good test to see how easy it is to use Elixir. Combined with something chosen from Erlang for a good reason.

#### Testme 1

The "Hello world" in the TCP land is an echo server for me. There are lots of examples how to do it and even Ranch has example code for it.

First I created my application with mix like this:

```mix new testme1 --sup```

Then I added the ranch dependency to the mix.exs:


Finally I started aligning the ranch's hello world example with the Elixir syntax. I ended up with the following files:

Everything looked OK to me except that it didn't work. There was no compile time or runtime errors. When I connected my telnet to the app I found that the port is open, but it closed the connection immediately. Still no errors. This was very disappointing.

### TestMe2

At my first disappointment, I decided to look for another alternative: barrel http://php-hackers.com/p/benoitc/barrel . I realized quite fast that it has no hex.pm support and it uses OTP 15 which is incompatible with my Elixir. At least I have no idea how to make these OTPs  work together.

Then I went back to hack ranch to work with Elixir. The solution was pretty easy. The parameter names from the Erlang example was all capitalized. From this point on my TCP acceptor worked like a breeze:


### Conclusion

I guess I learned the Elixir naming convention the hard way. Still I find annoying that I got no errors at compile time or runtime that I am doing something wrong. I envy people when I hear how much fun it is to learn a new programming language.
