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
    GenServer.cast(Watchman.Server, {:send, name, value, type})
  end

  def increment(name) do
    submit(name, 1, :count)
  end

  def decrement(name) do
    submit(name, -1, :count)
  end

  def benchmark(name, function) do
    {duration, result} = function |> :timer.tc
    submit(name, div(duration, 1000))
    result
  end

end
