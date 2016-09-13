defmodule Watchman do
  use Application

  defmacro __using__(_mod) do
    quote do
      import Watchman

      Module.register_attribute(__MODULE__, :watchman_benchmarks, accumulate: true)
      Module.register_attribute(__MODULE__, :watchman_counts, accumulate: true)

      @before_compile Watchman.Benchmark
      @on_definition Watchman.Benchmark

      @before_compile Watchman.Count
      @on_definition Watchman.Count
    end
  end

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
    submit(name, div(duration, 1000), :timing)
    result
  end
end
