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

Never name metric with variable:

```elixir
Watchman.submit("user.#{id}.count", 30)
```

If you need something like that, you probably need [tags](#tags)!

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
```

## Tags
If metrics family is needed, something like:
```
user.1.count
user.2.count
user.3.count
...
```

**NEVER** name metric like this:
```elixir
Watchman.increment("user.#{id}.count")
```
instead use tags, like this:
```elixir
Watchman.increment({"user.count", ["#{id}"]})
```

Second example will create 1 measurement in InfluxDB with tag value `"#{id}"`.
And it is right thing to do.

There can be 3 tag values at the most.
(If you need more - shout.)

## System metrics

You can gather system metrics simply by adding a `Watchman.System` worker to
your supervisor.

The following will send a bundle of metrics to your metrics server every `60`
seconds:

``` elixir
worker(Watchman.System, [[interval: 60]])
```

The following metrics are sent:

- system.memory.total
- system.memory.processes
- system.memory.processes_used
- system.memory.atom
- system.memory.atom_used
- system.memory.binary
- system.memory.code
- system.memory.ets

## Ecto Metrics

Watchman.Ecto is a custom built ecto logger that submits transaction data
to StatsD servers.

To use the logger add this Logger to your ecto configuration.

Example setup from `config/config.ex`:

```
repo_name = "example_repo"

config :my_app, MyApp.Repo,
  loggers: [
    {Ecto.LogEntry, :log, [:debug]},
    {Watchman.Ecto, :log, [repo_name]}
  ]
```

When set up, this will generate the following metrics:

```
1. total transaction counter
<watchman-prefix>.transaction.count, with tags: [repo_name, table_name]

2. the time spent executing the query in DB native units (nanosecs)
<watchman-prefix>.transaction.duration, with tags: [repo_name, table_name, "query"]

3. the time spent to check the connection out in DB native units (nanosecs)
<watchman-prefix>.transaction.duration, with tags: [repo_name, table_name, "queue"]

4. the time spent decoding the result in DB native units (nanosecs)
<watchman-prefix>.transaction.duration, with tags: [repo_name, table_name, "decode"]

5. total time spend for the transaction in DB native units (nanosecs)
<watchman-prefix>.transaction.duration, with tags: [repo_name, table_name, "total"]
```

## Advanced configuration

### Buffer Size

Watchman has a limited buffer size for unprocessed messages (metrics that are
waiting to be submitted via UDP).

This limit is set in order to avoid accidental accumulation of messages in
Watchman.Server's message box.

The default value is unprocessed 10_000 messages.

To change the default value, set a new value in the config:

``` elixir
config :watchman,
  host: "statistics.example.com",
  port: 22001,
  prefix: "my-service.prod"
  max_buffer_size: 50            # <----- sets the buffer to 50 messages
```
