# Watchman

Watchman is your friend who monitors your processes so you don't have to.

## Installation

Add the following to the list of your dependencies:

``` elixir
def deps do
  [
    {:watchman, github: "renderedtext/ex-watchman"}
  ]
end
```

Also, add it to the list of your applications:

``` elixir
def application do
  [applications: [:watchman]]
end
```

## Setup

First, set up the host and the port of the metrics server, and the prefix you
want to use. Example:

``` elixir
config :watchman,
  host: "statistics.example.com",
  port: 22001,
  prefix: "my-service.prod"
```

## Usage

### Heartbeat
To keep track if the application is running, use the heartbeat feature. Define
a child process in the supervisor with a defined interval between notifications
(in seconds), like so:

``` elixir
worker(Watchman.Heartbeat, [[interval: 1]])
```

### Submitting simple values

To submit a simple value from your service:

``` elixir
Watchman.submit("users.count", 30)
```

To submit a timing value:

``` elixir
Watchman.submit("installation.duration", 30, :timing)
```

### Counting

To increment a simple value from your service:

``` elixir
Watchman.increment("users.count")
```

to decrement:

``` elixir
Watchman.decrement("users.count")
```

You can also use the count annotation. Placed in front of a method, it will
count the number of times the method was called.

To count a method with an auto generated key in your module:
```elixir
defmodule Example do
  use Watchman.Count

  @count(key: :auto)
  def test
    :timer.sleep(10)
  end

end
```

To count a method while giving the metric a key:
```elixir
defmodule Example do
  use Watchman.Count

  @count(key: "lazy.test.function.that.only.sleeps.count")
  def test
    :timer.sleep(10)
  end

end
```

### Benchmarking

To benchmark a part of your service:

``` elixir
Watchman.benchmark("sleep.duration", fn ->
  IO.puts "Sleeping"
  :timer.sleep(10000)
  IO.puts "Wake up"
end)
```

To benchmark a function with an auto generated key in your module:

``` elixir
defmodule Example do
  use Watchman.Benchmark

  @benchmark(key: :auto)
  def test
    :timer.sleep(10)
  end

end
```

To benchmark a function while giving the metric a key:

``` elixir
defmodule Example do
  use Watchman.Benchmark

  @benchmark(key: "lazy.test.function.that.only.sleeps.benchmark")
  def test
    :timer.sleep(10)
  end

end
```

Please note that if the key is manually given, it cannot contain blank spaces.

To benchmark functions with multiple bodies, use only a single annotation:

``` elixir
defmodule Example do
  use Watchman.Benchmark

  @benchmark(key: :auto)
  def sum(a, b) when is_integer(a) and is_integer(b) do
    a + b
  end
  def sum(a, b) when is_list(a) and is_list(b) do
    a ++ b
  end
  def sum(a, b) when is_binary(a) and is_binary(b) do
    a <> b
  end

end
