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
  host: "statistics.example.com"
  port: 22001,
  prefix: "my-service.prod"
```

## Usage

To submit a simple value from your service:

``` elixir
Watchman.submit("users.count", 30)
```

To increment a simple value from your service:

``` elixir
Watchman.increment("users.count")
```

to decrement:

``` elixir
Watchman.decrement("users.count")
```

To submit a timing value:

``` elixir
Watchman.submit("installation.duration", 30, :timing)
```

To benchmark a part of your service:

``` elixir
Watchman.benchmark("sleep.duration", fn ->
  IO.puts "Sleeping"
  :timer.sleep(10000)
  IO.puts "Wake up"
end)
```

To benchmark a function in your module:

``` elixir
defmodule Example do
  use Watchman

  @benchmark
  def test
    :timer.sleep(10)
  end

end
```

To keep track if the application is running, use the heartbeat feature. Define a child process in the supervisor with a defined interval between notifications (in seconds), like so:

``` elixir
worker(Watchman.Heartbeat, [interval: 1])
```
