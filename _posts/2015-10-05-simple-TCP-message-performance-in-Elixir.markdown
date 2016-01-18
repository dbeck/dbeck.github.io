---
published: true
layout: post
category: Elixir
tags: 
  - elixir
  - performance
  - TCP
  - ranch
desc: Simple TCP message performance in Elixir
description: Simple TCP message performance in Elixir
keywords: "Elixir, TCP, Network, Performance, socket"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/IM000071.JPG
woopra: smallmsgex
---

I am still learning Elixir. I have programmed in a number of languages and learning new syntax is not a big deal for me. What I am more interested in is to understand what is the problem domain where the given language fits better.

I am interested in distributed, networked problems where Elixir is said to be good. I want to make a few experiments to see what I can expect. In this post I create a simple Elixir TCP server that receives small messages. These messages will have these 3 fields:

 - a 64 bit ID
 - a 32 bit size field that tells who many bytes the payload has
 - payload

I expect my TCP server to send back the message ID as an acknowledgement. I will create a C++ client to send the messages and check the ACKs. They will operate in lock-step, so the C++ client will send the new message when it verified the acknowledgment. 

**Update**: you may be also interested in the next three posts in this series:

 - [100k messages per second](/Four-Times-Speedup-By-Throttling/) achieved by the introduction of reply throttling
 - [250k messages per second](/Over-Two-Times-Speedup-By-Better-Elixir-Code/) achieved by better use of Elixir pattern matching
 - [over 2M messages per second](/Passing-Millions-Of-Small-TCP-Messages-in-Elixir/) achieved by removing the usage of the Task module

### Measurement

I am interested to see how many messages will go through this setup per second on average. I don't want to create any scientific measurement, neither want to compare this with other languages or solutions. I already know that this solution is not good. I only want a rough figure how would this perform on my laptop's loopback network.

### The Elixir server

I will use the [ranch](http://ninenines.eu/docs/en/ranch/1.1/) Erlang library for this experiment, although the default gen_tcp module would work perfectly here. I want to build on my [previous experiments](http://dbeck.github.io/Using-Ranch-From-Elixir/).

I created the project by ```mix new EchoPerf1 --sup --module EchoPerf1```.

The mix.exs file has:

``` elixir
defmodule Echoperf1.Mixfile do
  use Mix.Project

  def project do
    [app: :echoperf1,
     version: "0.0.1",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [
      applications: [:logger, :ranch],
      mod: {EchoPerf1, []}
    ]
  end

  defp deps do
    [{:ranch, "~> 1.1"}]
  end
end
```

```lib/echoperf1.ex``` has:

``` elixir
defmodule EchoPerf1 do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [ worker(EchoPerf1.Worker, []) ]
    opts = [strategy: :one_for_one, name: EchoPerf1.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

```lib/echoperf1_worker.ex``` has:

``` elixir
defmodule EchoPerf1.Worker do
  def start_link do
    opts = [port: 8000]
    {:ok, _} = :ranch.start_listener(:EchoPerf1, 10, :ranch_tcp, opts, EchoPerf1.Handler, [])
  end
end
```

The real work is done in ```lib/echoperf1_handler.ex```:

``` elixir
defmodule EchoPerf1.Handler do

  def start_link(ref, socket, transport, opts) do
    pid = spawn_link(__MODULE__, :init, [ref, socket, transport, opts])
    {:ok, pid}
  end

  def init(ref, socket, transport, _Opts = []) do
    :ok = :ranch.accept_ack(ref)
    loop(socket, transport)
  end

  def loop(socket, transport) do
    case transport.recv(socket, 12, 5000) do
      {:ok, id_sz_bin} ->
        << id :: binary-size(8), sz :: size(32) >> = id_sz_bin
        case transport.recv(socket, sz, 5000) do
          {:ok, _ } -> # data
            transport.send(socket, id)
            loop(socket, transport)
          {:error, :closed} ->
            :ok = transport.close(socket)
          {:error, :timeout} ->
            :ok = transport.close(socket)
          {:error, _} -> # err_message
            :ok = transport.close(socket)
          _ ->
            :ok = transport.close(socket)
        end
      _ ->
        :ok = transport.close(socket)          
    end
  end
end

```

I appreciate Elixir's simplicity and robustness. While I was creating this experiment I tested a lot with telnet and sent garbage to this server. Everything I tried worked sensibly and made perfect sense. This BTW is one of the outcomes that I was shooting at when designed this experiment.

### C++ client

I chose C++ to be the client because this is my primary language. I know what should be the performance when I write something into the code. This allows me to better understand the Elixir side too. If both were written in Elixir I would be in a very unfamiliar place.


The C++ client code:

``` C++
 #include <sys/types.h>
 #include <sys/socket.h>
 #include <sys/uio.h>
 #include <netinet/in.h>
 #include <arpa/inet.h>
 #include <string.h>
 #include <unistd.h>
 #include <stdio.h>

 #include <iostream>
 #include <functional>
 #include <cstdint>
 #include <chrono>

namespace
{
  struct on_destruct
  {
    std::function<void()> fun_;
    on_destruct(std::function<void()> fun) : fun_(fun) {}
    ~on_destruct() { fun_(); }
  };
  
  struct timer
  {
    typedef std::chrono::high_resolution_clock      highres_clock;
    typedef std::chrono::time_point<highres_clock>  timepoint;
    
    timepoint  start_;
    uint64_t   iteration_;
    
    timer(uint64_t iter) : start_{highres_clock::now()}, iteration_{iter} {}
      
    ~timer()
    {
      using namespace std::chrono;
      timepoint now{highres_clock::now()};
      
      uint64_t  usec_diff     = duration_cast<microseconds>(now-start_).count();
      double    call_per_ms   = iteration_*1000.0     / ((double)usec_diff);
      double    call_per_sec  = iteration_*1000000.0  / ((double)usec_diff);
      double    us_per_call   = (double)usec_diff     / (double)iteration_;
      
      std::cout << "elapsed usec=" << usec_diff
                << " avg(usec/call)=" << us_per_call
                << " avg(call/msec)=" << call_per_ms
                << " avg(call/sec)=" << call_per_sec
                << std::endl;
    }
  };
}


int main(int argc, char ** argv)
{
  try
  {
    // create a TCP socket
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if( sockfd < 0 )
    {
      throw "can't create socket";
    }
    on_destruct close_sockfd( [sockfd](){ close(sockfd); } );
    
    // server address (127.0.0.1:8000)
    struct sockaddr_in server_addr;
    ::memset(&server_addr, 0, sizeof(server_addr));
    
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    server_addr.sin_port = htons(8000);  
    
    // connect to server
    if( connect(sockfd, (struct sockaddr *)&server_addr, sizeof(struct sockaddr)) == -1 )
    {
      throw "failed to connect to server at 127.0.0.1:8000";
    }
    
    // prepare data
    char      data[]  = "Hello";
    uint64_t  id      = 0;
    uint32_t  len     = htonl(5);
      
    struct iovec data_iov[3] = {
      { (char *)&id,   8 }, // id
      { (char *)&len,  4 }, // len
      { data,          5 }  // data
    };
    
    for( int i=0; i<100; ++i )
    {
      timer t(10000);
      // send data in a loop
      for( id = 0; id<10000; ++id )
      {
        if( writev(sockfd, data_iov, 3) != 17 ) throw "failed to send data";
        uint64_t response = 0;
        if( recv(sockfd, &response, 8, 0) != 8 ) throw "failed to receive data";
        if( response != id ) throw "invalid response received";
      }
    }
    
  }
  catch( const char * msg )
  {
    perror(msg);
  }
  return 0;
}
```

I built the client on Mac OSX by running ```g++ -o EchoCpp1 -O3 -std=c++11 -Wall EchoCpp1.cc```.

### The results

I ran this on a 2015 MacBook Air.

```
elapsed usec=433476 avg(usec/call)=43.3476 avg(call/msec)=23.0693 avg(call/sec)=23069.3
elapsed usec=450325 avg(usec/call)=45.0325 avg(call/msec)=22.2062 avg(call/sec)=22206.2
elapsed usec=442094 avg(usec/call)=44.2094 avg(call/msec)=22.6196 avg(call/sec)=22619.6
elapsed usec=436530 avg(usec/call)=43.653 avg(call/msec)=22.9079 avg(call/sec)=22907.9
elapsed usec=447470 avg(usec/call)=44.747 avg(call/msec)=22.3479 avg(call/sec)=22347.9
elapsed usec=448915 avg(usec/call)=44.8915 avg(call/msec)=22.2759 avg(call/sec)=22275.9
elapsed usec=451250 avg(usec/call)=45.125 avg(call/msec)=22.1607 avg(call/sec)=22160.7
```

Roughly 22k message roundtrips per second.

### Conclusion

Being honest I was hoping that this is going to be faster. But I am not disappointed by the results. My next experiment will optimize the protocol because I suspect this lock step order is not a good fit for Elixir. Message throttling and asynch acknowledgement would help a lot, but yet to be tested.

For a few observations about local messaging performance here is an [older post](http://dbeck.github.io/price-of-being-distributed/).
