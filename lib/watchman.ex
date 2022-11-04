defmodule Watchman do
  use Application

  def start(_type, args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Watchman.Server, []),
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    opts = Keyword.merge(opts, args)

    Supervisor.start_link(children, opts)
  end

  def submit(name, value, type \\ :gauge)

  def submit({channel, name}, value, type) when channel in [:internal, :external, :always] do
    Watchman.Server.submit([{channel, name}], value, type)
  end

  def submit(names, value, type) when is_list(names) do
    Watchman.Server.submit(names, value, type)
  end

  def submit(name, value, type) do
    Watchman.Server.submit([{:internal, name}], value, type)
  end

  def increment(name), do: submit(name, 1, :count)

  def decrement(name), do: submit(name, -1, :count)

  def benchmark(name, function) do
    {duration, result} = function |> :timer.tc()
    submit(name, div(duration, 1000), :timing)
    result
  end
end
