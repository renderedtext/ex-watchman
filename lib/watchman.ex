defmodule Watchman do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Watchman.Server, []),
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  def submit(name, value, type \\ :gauge) do
    Watchman.Server.submit(name, value, false, type)
  end

  def submit(name, value, external, type) do
    Watchman.Server.submit(name, value, external, type)
  end

  def increment(name), do: increment(name, false)
  def increment(name, external) do
    submit(name, 1, external, :count)
  end

  def decrement(name), do: decrement(name, false)
  def decrement(name, external) do
    submit(name, -1, external, :count)
  end

  def benchmark(name, function), do: benchmark(name, false, function)
  def benchmark(name, external, function) do
    {duration, result} = function |> :timer.tc
    submit(name, div(duration, 1000), external, :timing)
    result
  end
end
