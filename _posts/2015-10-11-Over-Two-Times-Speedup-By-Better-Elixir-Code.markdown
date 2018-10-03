---
published: true
layout: post
category: Elixir
tags:
  - elixir
  - performance
  - TCP
desc: Two and a half times speedup gained by writing better Elixir code in the critical path of my TCP server
description: Two and a half times speedup gained by writing better Elixir code in the critical path of my TCP server
keywords: "Elixir, TCP, Network, Performance, socket"
twcardtype: summary_large_image
twimage: http://dbeck.github.io/images/BatchPerf.png
pageid: batchmsgex
---

This is the third episode of my experiments with Elixir TCP programming. My goal is to improve my Elixir programming skills by choosing a problem that I am interested in. That is how to handle large number of small messages in a TCP server program.

My [first attempt](/simple-TCP-message-performance-in-Elixir/) gave **22k messages per second** on a single connection. This used a traditional Request/Reply pattern that is not the best for small messages because we pay too much overhead for each message.

In the [second attempt](/Four-Times-Speedup-By-Throttling/) I changed the pattern and allowed the client to slightly run ahead of the server by allowing the server to batch the replies. With this change I arrived to the **100k messages per second** range. However this was still not looking good because the test did around 2MB/second on the loopback network which is slow. The server also didn't scale by CPU cores.

My gut feeling was that I am doing a mistake in the Elixir program that needs to be fixed. The whole server seemed to be CPU heavy. The other thing I didn't like is that I am doing OS calls for each message on the client side and two OS calls on the server side. This is asking for trouble in my books.

This experiment improved both the OS call issues and the Elixir code improved quite a bit. The result is roughly **250k messages per second**.

**Update**: you may be also interested in the last post in this series:

 - [over 2M messages per second](/Passing-Millions-Of-Small-TCP-Messages-in-Elixir/) achieved by removing the usage of the Task module

### The results

```
elapsed usec=729471 avg(usec/call)=3.64736 avg(call/msec)=274.171 avg(call/sec)=274171
elapsed usec=786650 avg(usec/call)=3.93325 avg(call/msec)=254.243 avg(call/sec)=254243
elapsed usec=780018 avg(usec/call)=3.90009 avg(call/msec)=256.404 avg(call/sec)=256404
elapsed usec=780898 avg(usec/call)=3.90449 avg(call/msec)=256.115 avg(call/sec)=256115
elapsed usec=780172 avg(usec/call)=3.90086 avg(call/msec)=256.354 avg(call/sec)=256354
elapsed usec=773731 avg(usec/call)=3.86865 avg(call/msec)=258.488 avg(call/sec)=258488
elapsed usec=811105 avg(usec/call)=4.05553 avg(call/msec)=246.577 avg(call/sec)=246577
elapsed usec=780474 avg(usec/call)=3.90237 avg(call/msec)=256.255 avg(call/sec)=256255
elapsed usec=824067 avg(usec/call)=4.12033 avg(call/msec)=242.699 avg(call/sec)=242699
elapsed usec=786796 avg(usec/call)=3.93398 avg(call/msec)=254.195 avg(call/sec)=254195
elapsed usec=762324 avg(usec/call)=3.81162 avg(call/msec)=262.356 avg(call/sec)=262356
elapsed usec=785777 avg(usec/call)=3.92889 avg(call/msec)=254.525 avg(call/sec)=254525
elapsed usec=767962 avg(usec/call)=3.83981 avg(call/msec)=260.43 avg(call/sec)=260430
elapsed usec=810479 avg(usec/call)=4.05239 avg(call/msec)=246.768 avg(call/sec)=246768
elapsed usec=788926 avg(usec/call)=3.94463 avg(call/msec)=253.509 avg(call/sec)=253509
elapsed usec=788894 avg(usec/call)=3.94447 avg(call/msec)=253.519 avg(call/sec)=253519
elapsed usec=768952 avg(usec/call)=3.84476 avg(call/msec)=260.094 avg(call/sec)=260094
elapsed usec=763300 avg(usec/call)=3.8165 avg(call/msec)=262.02 avg(call/sec)=262020
elapsed usec=757870 avg(usec/call)=3.78935 avg(call/msec)=263.898 avg(call/sec)=263898
elapsed usec=749668 avg(usec/call)=3.74834 avg(call/msec)=266.785 avg(call/sec)=266785
```

The 2.5x speedup is good at first sight, however I am still not happy. The Elixir code has too high CPU utilization, and it also doesn't scale with cores when I start multiple clients. I have a few other ideas to speed this up by improving my Elixir code.

### Elixir server changes

I have renamed all **ThrottlePerf** references to **Batch**. The real changes is in ```lib/batch_handler.ex```. I include the source code below.

Instead of doing two ```transport.recv``` calls for each message I try to read everything available in a single step and parse the buffer.

The old ```ThrottlePerf``` code has:

``` elixir
  def loop(socket, transport, container, timer_pid) do
    case transport.recv(socket, 12, 5000) do
      {:ok, id_sz_bin} ->
        << id :: binary-size(8), sz :: little-size(32) >> = id_sz_bin
        case transport.recv(socket, sz, 5000) do
          {:ok, data} ->
            ThrottlePerf.Container.push(container, id, data)
            loop(socket, transport, container, timer_pid)
          {:error, :timeout} ->
            flush(socket, transport, container)
            shutdown(socket, transport, container, timer_pid)
          _ ->
            shutdown(socket, transport, container, timer_pid)
        end
      _ ->
        shutdown(socket, transport, container, timer_pid)
    end
  end
```

The new code in contrast introduces a more Elixirish recursive call ```process``` to handle the incoming data:

``` elixir
  def loop(socket, transport, container, timer_pid, yet_to_parse) do
    case transport.recv(socket, 0, 5000) do
      {:ok, packet} ->
        not_yet_parsed = process(container, yet_to_parse <> packet)
        loop(socket, transport, container, timer_pid, not_yet_parsed)
      {:error, :timeout} ->
        flush(socket, transport, container)
        shutdown(socket, transport, container, timer_pid)
      _ ->
        shutdown(socket, transport, container, timer_pid)
    end
  end

  defp process(_container, << >> ) do
    << >>
  end

  defp process(container, packet) do
    case packet do
      << id :: binary-size(8), sz :: little-size(32) , data :: binary-size(sz) >> ->
        Batch.Container.push(container, id, data)
        << >>
      << id :: binary-size(8), sz :: little-size(32) , data :: binary-size(sz) , rest :: binary >> ->
        Batch.Container.push(container, id, data)
        process(container, rest)
      unparsed ->
        unparsed
      end
  end
```

The point when I made this change was when the 2.5x speedup arrived.

### C++ client changes

The change in the C++ client is that now I am batching multiple writes into a single ```writev()``` call by piling up IOV structures. This allows the OS to combine multiple writes into less writes. This seemed to be a great idea but in practice if I used the older C++ client without this change the difference was small. Only the CPU utilization of the C++ client has dropped to half (5%).

I still like this idea so I'll keep it. The protocol has not changed, so I can use either clients to test with. You can find the source code at the end of this post.

### Elixir server source

``` elixir
defmodule Batch.Handler do

  def start_link(ref, socket, transport, opts) do
    pid = spawn_link(__MODULE__, :init, [ref, socket, transport, opts])
    {:ok, pid}
  end

  def init(ref, socket, transport, _Opts = []) do
    :ok = :ranch.accept_ack(ref)
    {:ok, container} = Batch.Container.start_link
    timer_pid = spawn_link(__MODULE__, :timer, [socket, transport, container])
    transport.setopts(socket, [nodelay: :true])
    loop(socket, transport, container, timer_pid, << >>)
  end

  def flush(socket, transport, container) do
    list = Batch.Container.flush(container)
    case Batch.Container.generate_ack(list) do
      {id, skipped} ->
        packet = << id :: binary-size(8), skipped :: little-size(32) >>
        transport.send(socket, packet)
      {} ->
        :ok
    end
  end

  def timer(socket, transport, container) do
    flush(socket, transport, container)
    receive do
      {:stop} -> :stop
    after
      5 -> timer(socket, transport, container)
    end
  end

  def loop(socket, transport, container, timer_pid, yet_to_parse) do
    case transport.recv(socket, 0, 5000) do
      {:ok, packet} ->
        not_yet_parsed = process(container, yet_to_parse <> packet)
        loop(socket, transport, container, timer_pid, not_yet_parsed)
      {:error, :timeout} ->
        flush(socket, transport, container)
        shutdown(socket, transport, container, timer_pid)
      _ ->
        shutdown(socket, transport, container, timer_pid)
    end
  end

  defp shutdown(socket, transport, container, timer_pid) do
    Batch.Container.stop(container)
    :ok = transport.close(socket)
    send timer_pid, {:stop}
  end

  defp process(_container, << >> ) do
    << >>
  end

  defp process(container, packet) do
    case packet do
      << id :: binary-size(8), sz :: little-size(32) , data :: binary-size(sz) >> ->
        Batch.Container.push(container, id, data)
        << >>
      << id :: binary-size(8), sz :: little-size(32) , data :: binary-size(sz) , rest :: binary >> ->
        Batch.Container.push(container, id, data)
        process(container, rest)
      unparsed ->
        unparsed
      end
  end
end

```

### The C++ client source

The single biggest change in the C++ code is the introduction of ```buffer<MAX_ITEMS>``` structure that allows me to batch a **MAX_ITEMS** messages together to write in a single step.

I also experimented with the ```setsockopt(TCP_NODELAY)``` option but this didn't make any difference.

``` C++
 #include <sys/types.h>
 #include <sys/socket.h>
 #include <sys/uio.h>
 #include <sys/select.h>
 #include <netinet/in.h>
 #include <netinet/tcp.h>
 #include <arpa/inet.h>
 #include <string.h>
 #include <unistd.h>
 #include <stdio.h>

 #include <iostream>
 #include <functional>
 #include <cstdint>
 #include <chrono>
 #include <thread>

namespace
{
  //
  // to help freeing C resources
  //
  struct on_destruct
  {
    std::function<void()> fun_;
    on_destruct(std::function<void()> fun) : fun_(fun) {}
    ~on_destruct() { if( fun_ ) fun_(); }
  };

  //
  // for measuring ellapsed time and print statistics
  //
  struct timer
  {
    typedef std::chrono::high_resolution_clock      highres_clock;
    typedef std::chrono::time_point<highres_clock>  timepoint;

    timepoint  start_;
    uint64_t   iteration_;

    timer(uint64_t iter) : start_{highres_clock::now()}, iteration_{iter} {}

    int64_t spent_usec()
    {
      using namespace std::chrono;
      timepoint now{highres_clock::now()};
      return duration_cast<microseconds>(now-start_).count();
    }

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

  template <size_t MAX_ITEMS>
  struct buffer
  {
    // each packet has 3 parts:
    // - 64 bit ID
    // - 32 bit size
    // - data
    struct iovec   items_[MAX_ITEMS*3];
    uint64_t       ids_[MAX_ITEMS];
    size_t         n_items_;
    uint32_t       len_;
    char           data_[5];

    buffer() : n_items_{0}, len_{5}
    {
      memcpy(data_, "hello", 5);

      for( size_t i=0; i<MAX_ITEMS; ++i )
      {
        // I am cheating with the packet content to be fixed
        // to "hello", but for the purpose of this test app
        // it is OK.
        //
        ids_[i] = 0;
        // the ID
        items_[i*3].iov_base = (char*)(ids_+i);
        items_[i*3].iov_len  = sizeof(*ids_);
        // the size
        items_[(i*3)+1].iov_base = (char*)(&len_);
        items_[(i*3)+1].iov_len  = sizeof(len_);
        // the data
        items_[(i*3)+2].iov_base = data_;
        items_[(i*3)+2].iov_len  = len_;
      }
    }

    void push(uint64_t id)
    {
      ids_[n_items_++] = id;
    }

    bool needs_flush() const
    {
      return (n_items_ >= MAX_ITEMS);
    }

    void flush(int sockfd)
    {
      if( !n_items_ ) return;
      if( writev(sockfd, items_, (n_items_*3)) != (17*n_items_) )
      {
        throw "failed to send data";
      }
      n_items_ = 0;
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

    {
      int flag = 1;
      if( setsockopt( sockfd, IPPROTO_TCP, TCP_NODELAY, (void *)&flag, sizeof(flag)) == -1 )
      {
        throw "failed to set TCP_NODELAY on the socket";
      }
    }

    // the buffer template parameter tells how many messages shall
    // we batch together
    buffer<50>   data;
    uint64_t     id            = 0;
    int64_t      last_ack      = -1;

    //
    // this lambda function checks if we have received a new ACK.
    // if we did then it checks the content and returns the max
    // acknowledged ID. this supports receiving multiple ACKs in
    // a single transfer.
    //
    auto check_ack = [sockfd](int64_t last_ack) {
      int64_t ret_ack = last_ack;
      fd_set fdset;
      FD_ZERO(&fdset);
      FD_SET(sockfd, &fdset);

      // give 10 msec to the acks to arrive
      struct timeval tv { 0, 10000 };
      int select_ret = select( sockfd+1, &fdset, NULL, NULL, &tv );
      if( select_ret < 0)
      {
        throw "failed to select, socket error?";
      }
      else if( select_ret > 0 && FD_ISSET(sockfd,&fdset) )
      {
        // max 2048 acks that we handle in one check
        size_t alloc_bytes = 12 * 2048;
        std::unique_ptr<uint8_t[]> ack_data{new uint8_t[alloc_bytes]};

        //
        // let's receive what has arrived. if there are more than 2048
        // ACKs waiting, then the next loop will take care of them
        //

        auto recv_ret = recv(sockfd, ack_data.get(), alloc_bytes, 0);
        if( recv_ret < 0 )
        {
          throw "failed to recv, socket error?";
        }
        if( recv_ret > 0 )
        {
          for( size_t pos=0; pos<recv_ret; pos+=12 )
          {
            uint64_t id = 0;
            uint32_t skipped = 0;

            // copy the data to the variables above
            //
            memcpy(&id, ack_data.get()+pos, sizeof(id) );
            memcpy(&skipped, ack_data.get()+pos+sizeof(id), sizeof(skipped) );

            // check the ACKs
            if( (ret_ack + skipped + 1) != id )
            {
              throw "missing ack";
            }
            ret_ack = id;
          }
        }
      }
      return ret_ack;
    };

    for( int i=0; i<20; ++i )
    {
      size_t iter = 200000;
      timer t(iter);
      int64_t checked_at_usec = 0;

      // send data in a loop
      for( size_t kk=0; kk<iter; ++kk )
      {
        data.push(id);
        if( data.needs_flush() )
        {
          data.flush(sockfd);
        }

        //
        // check time after every 1000 send so I reduce
        // OS calls by not querying time too often
        //
        if( (kk%1000) == 0 )
        {
          //
          // check if at least 30 msecs has ellapsed since the
          // last ACK check
          //
          int64_t spent_usec = t.spent_usec();
          if( spent_usec > (checked_at_usec+30000) )
          {
            last_ack = check_ack(last_ack);
            checked_at_usec = spent_usec;
          }
        }
        ++id;
      }

      // flush all unflushed items
      data.flush(sockfd);

      // wait for all outstanding ACKs
      while( last_ack < (id-1) )
        last_ack = check_ack(last_ack);
    }

    while( last_ack < (id-1) )
    {
      last_ack = check_ack(last_ack);
      if( last_ack != id )
      {
        std::cerr << "last_ack=" << last_ack << " id=" << id << "\n";
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));
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
